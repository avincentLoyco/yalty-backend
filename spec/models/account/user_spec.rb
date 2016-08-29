require 'rails_helper'

RSpec.describe Account::User, type: :model do
  subject { build(:account_user) }
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

  describe 'intercom integration' do
    include_context 'shared_context_intercom_attributes'
    let(:account) { user.account }
    let(:user) { create(:account_user) }

    it 'is of type :users' do
      expect(user.intercom_type).to eq(:users)
    end

    it 'includes proper attributes' do
      expect(user.intercom_attributes).to eq(proper_user_intercom_attributes)
    end

    context 'as user only' do
      it 'returns proper data' do
        data_keys = user.intercom_data.keys + user.intercom_data[:custom_attributes].keys
        expect(data_keys).to match_array(proper_user_data_keys)
      end
    end

    context 'as employee' do
      before do
        create(:employee, account: account, user: user)
      end

      it 'returns proper data' do
        data_keys = user.intercom_data.keys + user.intercom_data[:custom_attributes].keys
        expect(data_keys).to match_array(proper_user_data_keys)
      end
    end
  end
end
