require 'rails_helper'

RSpec.describe Account::User, type: :model do
  subject { build(:account_user) }

  let(:account) { create(:account) }

  it { is_expected.to have_db_column(:id).of_type(:uuid) }
  it { is_expected.to have_db_column(:email).with_options(null: false) }
  it { is_expected.to have_db_index([:email, :account_id]).unique(true) }

  it { is_expected.to validate_presence_of(:email) }
  it { is_expected.to allow_value('test@test.com').for(:email) }
  it { is_expected.to_not allow_value('testtest.com').for(:email) }
  it { is_expected.to_not allow_value('testtestcom').for(:email) }
  it { is_expected.to_not allow_value('test@testcom').for(:email) }
  it { is_expected.to validate_uniqueness_of(:email).scoped_to(:account_id).case_insensitive }

  it { is_expected.to have_db_column(:password_digest).with_options(null: false) }
  it { is_expected.to validate_confirmation_of(:password) }
  it { is_expected.to validate_length_of(:password).is_at_least(8).is_at_most(74) }
  it { is_expected.to have_db_column(:reset_password_token).of_type(:string) }

  it { is_expected.to have_db_column(:role).of_type(:string).with_options(null: false) }
  it { is_expected.to validate_inclusion_of(:role).in_array(%w(user account_administrator account_owner))}

  it { is_expected.to have_db_column(:locale).of_type(:string).with_options(null: true) }
  it { is_expected.to validate_inclusion_of(:locale).in_array(I18n.available_locales.map(&:to_s)) }

  it 'should validate length of password only when is updated' do
    user = create(:account_user)
    user = Account::User.find(user.id)

    expect(user).to be_valid
  end

  it 'should generate password on creation if not present' do
    user = build(:account_user, password: nil)
    expect(user.password).to be_nil

    user.save

    expect(user.password).to_not be_nil
  end

  it 'should not overwrite password on creation if present' do
    user = build(:account_user, password: '1234567890')

    user.save

    expect(user).to be_persisted
    expect(user.password).to eql('1234567890')
  end

  it 'should validate presence of password on update' do
    user = create(:account_user)

    user.password = nil

    expect(user).to_not be_valid
  end

  it 'should not allow to change role of last owner' do
    user = create(:account_user, account: account, role: 'account_owner')

    expect { user.update(role: 'account_administrator') }.to_not change { user.reload.role }
  end

  it 'should allow to change role of not last owner' do
    users = create_list(:account_user, 2, account: account, role: 'account_owner')

    expect { users.first.update(role: 'account_administrator') }.to change { users.first.reload.role }
  end

  it 'should not allow to destroy last owner' do
    user = create(:account_user, account: account, role: 'account_owner')

    expect { user.destroy }.to_not change { Account::User.count }
  end

  it 'should allow to destroy not last owner' do
    users = create_list(:account_user, 2, account: account,  role: 'account_owner')

    expect { users.first.destroy }.to change { Account::User.count }.by(-1)
  end

  it { should have_db_column(:account_id).of_type(:uuid) }
  it { should have_db_index(:account_id) }
  it { should belong_to(:account).inverse_of(:users) }

  it '#current= should accept an user' do
    user = create(:account_user)

    expect(Account::User).to respond_to(:current=)
    expect {
      Account::User.current = user
    }.to_not raise_error
  end

  it '#current should return user' do
    user = create(:account_user)
    Account::User.current = user

    expect(Account::User.current).to eql(user)
  end

  it 'should validate reset password token uniqueness' do
    first_user = build(:account_user, :with_reset_password_token)
    second_user = first_user.dup

    first_user.save!

    expect { second_user.save }.to change { second_user.errors.messages[:reset_password_token] }
  end

  describe 'referrer' do
    let(:user) { build(:account_user) }
    subject(:create_user) { user.save! }

    it { expect { create_user }.to change(Referrer, :count).by(1) }
    it do
      create_user
      expect(user.reload.referrer).to be_a(Referrer)
    end
  end

  describe 'intercom integration' do
    include_context 'shared_context_intercom_attributes'
    let(:account) { user.account }
    let(:user) { create(:account_user) }
    let(:data_keys) { user.intercom_data.keys + user.intercom_data[:custom_attributes].keys }

    it { expect(user.intercom_type).to eq(:users) }
    it { expect(user.intercom_attributes).to eq(proper_user_intercom_attributes) }

    context 'as user only' do
      it { expect(data_keys).to match_array(proper_user_data_keys) }
    end

    context 'as employee' do
      before { create(:employee, account: account, user: user) }

      it { expect(data_keys).to match_array(proper_user_data_keys) }
    end
  end

  describe '#owner_or_administrator?' do
    let(:owner) { create(:account_user, role: 'account_owner') }
    let(:manager) { create(:account_user, role: 'account_administrator') }
    let(:user) { create(:account_user, role: 'user') }

    it { expect(owner.owner_or_administrator?).to be(true) }
    it { expect(manager.owner_or_administrator?).to be(true) }
    it { expect(user.owner_or_administrator?).to be(false) }
  end

  describe 'stripe callbacks' do
    let(:customer) { StripeCustomer.new('cus123', 'Some description', 'test@email.com') }
    let(:subscription) { StripeSubscription.new('sub_123') }

    before do
      allow_any_instance_of(Account::User).to receive(:stripe_enabled?).and_return(true)
      allow(Stripe::Customer).to receive(:retrieve).and_return(customer)
      allow(Stripe::Customer).to receive(:create).and_return(customer)
      allow(Stripe::Subscription).to receive(:create).and_return(subscription)
    end

    context 'update_stripe_customer_email' do
      shared_examples 'update stripe email' do
        it 'triggers update method' do
          expect(user).to receive(:update_stripe_customer_email)
          subject
        end

        it 'triggers update job' do
          expect(Payments::UpdateStripeCustomerDescription)
            .to receive(:perform_later)
            .with(account)
          subject
        end

        it { expect { subject }.to change(account, :stripe_email) }
      end

      let(:account) do
        create(:account, customer_id: 'cus_123', company_name: 'Omnics', subdomain: 'omnics')
      end
      let!(:first_user) do
        create(:account_user,
          account: account,
          email: 'first@email.com', role: 'account_owner',
          created_at: 1.month.ago)
      end
      let!(:second_user) do
        create(:account_user,
          account: account,
          email: 'second@email.com', role: 'account_owner',
          created_at: 1.day.ago)
      end

      context 'when non stripe user email changes' do
        subject { user.update!(email: 'change@test.com') }

        let(:user) { second_user }

        it { expect { subject }.to_not change(account, :stripe_email) }
      end

      context 'when stripe user email changes' do
        subject { user.update!(email: 'change@test.com') }

        let(:user) { first_user }

        it_behaves_like 'update stripe email'
      end

      context 'when stripe user is destroyed' do
        subject { user.destroy }

        let(:user) { first_user }

        it_behaves_like 'update stripe email'
      end

      context 'when stripe user lose account ownership' do
        subject { user.update!(role: 'account_administrator') }

        let(:user) { first_user }

        it_behaves_like 'update stripe email'
      end
    end
  end

  context 'yalty role' do
    subject { create(:account_user, email: email, role: 'yalty') }

    let!(:email) { ENV['YALTY_ACCESS_EMAIL'] = 'access@example.com' }

    it 'should not be changed to another role' do
      subject.role = 'account_owner'
      expect(subject).to_not be_valid
    end

    it 'should not allowed to update email' do
      subject.email = 'another@email.com'
      expect(subject).to_not be_valid
    end

    it 'should not allowed to update password' do
      subject.password = '1234567890'
      subject.password_confirmation = '1234567890'
      expect(subject).to_not be_valid
    end

    it 'should not allowed to add related employee' do
      user = build(:account_user, email: email, role: 'yalty')
      user.employee = create(:employee)
      expect(user).to_not be_valid

      subject.employee = create(:employee)
      expect(subject).to_not be_valid
    end

    it 'should not be allowed to exist more than once per account' do
      user = build(:account_user, account: subject.account, email: email, role: 'yalty')
      expect(user).to_not be_valid
    end

    it 'should not allow usage of yalty user email to user withtout yalty role' do
      user = build(:account_user, email: email, role: 'account_administrator')
      expect(user).to_not be_valid
    end

    it 'should allow usage of yalty user email to user with yalty role' do
      user = build(:account_user, email: email, role: 'yalty')
      expect(user).to be_valid
    end

    it 'should require yalty user email for user with yalty role' do
      user = build(:account_user, email: 'another.email@example.com', role: 'yalty')
      expect(user).to_not be_valid
    end
  end
end
