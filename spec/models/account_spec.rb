require 'rails_helper'

RSpec.describe Account, type: :model do
  subject { build(:account, subdomain: 'subdomain') }

  it { is_expected.to have_db_column(:id).of_type(:uuid) }
  it { is_expected.to have_db_column(:customer_id).of_type(:string) }
  it { is_expected.to have_db_column(:available_modules).of_type(:json) }
  it { is_expected.to have_db_column(:subscription_renewal_date).of_type(:date) }
  it { is_expected.to have_db_column(:subdomain).with_options(null: false) }
  it { is_expected.to have_db_column(:invoice_company_info).of_type(:hstore) }
  it { is_expected.to have_db_column(:invoice_emails).of_type(:text) }
  it { is_expected.to have_db_column(:archive_processing).of_type(:boolean).with_options(default: false) }
  it { is_expected.to have_db_column(:company_name) }
  it { is_expected.to have_db_index(:subdomain).unique(true) }
  it { is_expected.to validate_presence_of(:subdomain).on(:update) }
  it { is_expected.to validate_uniqueness_of(:subdomain).case_insensitive }
  it { is_expected.to validate_length_of(:subdomain).is_at_most(63) }
  it { is_expected.to allow_value('a', 'subdomain', 'sub-domain', '123subdomain', 'subdomain-123').for(:subdomain) }
  it { is_expected.to_not allow_value('-subdomain', 'subdomain-', 'sub domain', 'subdömaìn', 'SubDomain').for(:subdomain) }
  it { is_expected.to validate_exclusion_of(:subdomain).in_array(['www', 'staging']) }
  it { is_expected.to validate_presence_of(:company_name) }

  it { is_expected.to have_many(:employee_events).through(:employees) }
  it { is_expected.to have_many(:employee_attribute_versions).through(:employees) }
  it { is_expected.to have_many(:presence_policies) }
  it { is_expected.to have_many(:time_off_categories) }
  it { is_expected.to have_many(:invoices) }
  it { is_expected.to have_many(:working_places) }
  it { is_expected.to have_many(:users).class_name('Account::User').inverse_of(:account) }
  it { is_expected.to have_many(:employees).inverse_of(:account) }
  it { is_expected.to have_many(:employee_attribute_definitions).class_name('Employee::AttributeDefinition').inverse_of(:account) }
  it { is_expected.to have_one(:registration_key) }
  it { is_expected.to have_one(:archive_file).class_name('GenericFile') }

  context 'generate subdomain from company name on create' do

    it 'should not be blank' do
      account = build(:account, subdomain: nil, company_name: 'Company')

      expect(account).to be_valid
      expect(account.subdomain).to_not be_blank
    end

    { #  Company Name        subdomain
         'The Company'   =>  'the-company',
         '123 éàïôù'     =>  '123-eaiou',
         ':ratio'        =>  'ratio',
         'Dash--Company' =>  'dash-company',
         '--dash first ' =>  'dash-first',
         ' dash  last--' =>  'dash-last'
    }.each do |company_name, subdomain|

      it "should transcode `#{company_name}` to `#{subdomain}`" do
        account = build(:account, subdomain: nil, company_name: company_name)

        expect(account).to be_valid
        expect(account.subdomain).to eql(subdomain)
      end

    end

    it 'must be unique' do
      create(:account, subdomain: nil, company_name: 'The Company')
      account = build(:account, subdomain: nil, company_name: 'The Company')

      expect(account).to be_valid
      expect(account.subdomain).to match(/\Athe-company-[0-9]+\z/)
    end

  end

  context 'default attribute definitions' do
    it 'should create definitions on create' do
      account = build(:account)

      expect {
        account.save
      }.to change(Employee::AttributeDefinition, :count)

    end

    it 'should not add definitions if allready exist' do
      account = create(:account)

      expect {
        account.update_default_attribute_definitions!
      }.to_not change(Employee::AttributeDefinition, :count)

    end
  end

  context 'default time off categories' do
    it 'should create default time off categories' do
      account = build(:account)

      expect { account.save }.to change { TimeOffCategory.count }
    end

    it 'should not create default time off categories when alreadye exist' do
      account = create(:account)

      expect {
        account.update_default_time_off_categories!
      }.to_not change { TimeOffCategory.count }
    end

    context 'doesn\'t create \'other\' category anymore' do
      let(:account) { create(:account) }
      let(:category_names) { account.time_off_categories.pluck(:name) }

      it { expect(account.time_off_categories.count).to eq(5) }
      it { expect(category_names).to_not include('other') }
    end
  end

  context 'validations for default attribute definitions' do
    let(:account) { create(:account) }

    it 'should add presence: true validation for attributes in ATTR_VALIDATIONS' do
      required = account.employee_attribute_definitions.where(name: Account::ATTR_VALIDATIONS.keys)

      required.each do |attr|
        expect(attr.validation).to eq({ 'presence' => true })
      end
    end

    it 'should not add validation for other attributes' do
      not_required = account.employee_attribute_definitions
                        .where.not(name: Account::ATTR_VALIDATIONS.keys)

      not_required.each do |attr|
        expect(attr.validation).to eq(nil)
      end
    end
  end

  it '#users should not include user with yalty role' do
    account = create(:account)
    user = create(:account_user, :with_yalty_role, account: account)

    expect(account.reload.users).to_not include(user)
  end

  it '#current= should accept an account' do
    account = create(:account)

    expect(Account).to respond_to(:current=)
    expect {
      Account.current = account
    }.to_not raise_error
  end

  it '#current should return account' do
    account = create(:account)
    Account.current = account

    expect(Account.current).to eql(account)
  end

  context '#timezone' do
    it 'should save account with default rails timezone name' do
      timezone_name = ActiveSupport::TimeZone.all.sample.tzinfo.name
      account = build(:account, timezone: timezone_name)

      expect(account).to be_valid
      expect(account.timezone).to eq(timezone_name)
    end

    it 'should save account with UTC timezone name' do
      timezone_name = 'UTC'
      account = build(:account, timezone: timezone_name)

      expect(account).to be_valid
      expect(account.timezone).to eq(timezone_name)
    end

    it 'should save account with Europe/Zurich timezone name' do
      timezone_name = 'Europe/Zurich'
      account = build(:account, timezone: timezone_name)

      expect(account).to be_valid
      expect(account.timezone).to eq(timezone_name)
    end

    it 'should not save account with not valid timezone name' do
      account = build(:account, timezone: 'Pluto')

      expect(account).to_not be_valid
    end
  end

  context 'referred_by' do
    let(:referrer) { create(:referrer, token: '1234') }
    let(:valid_account) { build(:account, referred_by: referrer.token) }
    let(:invalid_account) { build(:account, referred_by: '5678') }

    it { expect { valid_account.save! }.not_to raise_error }
    it do
      expect { invalid_account.save! }.to raise_error(
        ActiveRecord::RecordInvalid,
        'Validation failed: Referred by must belong to existing referrer'
      )
    end
  end

  context 'for employee_files' do
    let(:account) { create(:account) }
    let(:employees) { create_list(:employee, 3, account: account) }
    let(:employee_files) { create_list(:generic_file, 3, :with_jpg) }
    let!(:employee_attributes) do
      employee_files.each do |file|
        create(:employee_attribute, employee: employees.sample, attribute_type: 'File', data: {
          id: file.id,
          size: file.file_file_size,
          file_type: file.file_content_type,
          file_sha: '123'
        })
      end
    end
    let(:total_amount_of_data) { employee_files.sum(&:file_file_size) / (1024.0 * 1024.0) }

    it { expect(account.total_amount_of_data).to eq(total_amount_of_data.round(2)) }
    it { expect(account.number_of_files).to eq(3) }
  end

  context 'reset resources' do
    let(:default_categories_count) { TimeOffCategory::DEFAULT.size }

    it { expect { subject.save! }.to change(PresencePolicy, :count).by(1) }
    it { expect { subject.save! }.to change(WorkingPlace, :count).by(1) }
    it { expect { subject.save! }.to change(TimeOffCategory, :count).by(default_categories_count) }
    it { expect { subject.save! }.to change(TimeOffPolicy, :count).by(default_categories_count) }

    context 'resources have reset flag' do
      before { subject.save! }

      it { expect(subject.presence_policies.last.reset).to be(true) }
      it { expect(subject.working_places.last.reset).to be(true) }
      it { expect(subject.time_off_policies.pluck(:reset).uniq.first).to be(true) }
    end
  end

  context '#update_stripe_customer_description' do
    let(:customer) { StripeCustomer.new('cus123', 'Some description', 'test@email.com') }
    let(:subscription) { StripeSubscription.new('sub_123') }

    before do
      allow_any_instance_of(Account).to receive(:stripe_enabled?).and_return(true)
      allow(Stripe::Customer).to receive(:retrieve).and_return(customer)
      allow(Stripe::Customer).to receive(:create).and_return(customer)
      allow(Stripe::Subscription).to receive(:create).and_return(subscription)
    end

    shared_examples 'update stripe description' do
      it 'triggers update method' do
        expect(account).to receive(:update_stripe_customer_description)
        subject
      end

      it 'triggers update job' do
        expect(Payments::UpdateStripeCustomerDescription)
          .to receive(:perform_later)
          .with(account)
        subject
      end

      it { expect { subject }.to change(account, :stripe_description) }
    end

    let(:account) do
      create(:account, customer_id: 'cus_123', company_name: 'Omnics', subdomain: 'omnics')
    end

    context 'when subdomain changes' do
      subject { account.update(subdomain: 'lumeri-co') }

      it_behaves_like 'update stripe description'
    end

    context 'when company_name changes' do
      subject { account.update(company_name: 'LumeriCo') }

      it_behaves_like 'update stripe description'
    end

    context 'when subdomain and company_name changes' do
      subject { account.update(subdomain: 'lumeri-co', company_name: 'LumeriCo') }

      it_behaves_like 'update stripe description'
    end
  end

  context '#yalty_access' do
    subject { create(:account) }

    it 'should be true when account have a user with yalty role' do
      user = create(:account_user, :with_yalty_role, account: subject)

      expect(subject.reload.yalty_access).to be_truthy
    end

    it 'should be false when account doesn\'t have a user with yalty role' do
      expect(subject.reload.yalty_access).to be_falsey
    end
  end

  context '#yalty_access=' do
    subject { create(:account) }

    describe 'when set to true' do
      it 'should create user with yalty role if not exists' do
        expect(subject.yalty_access).to be_falsey
        subject.yalty_access = true
        expect(subject.yalty_access).to be_truthy
        expect(subject.changes).to include(:yalty_access)
        expect { subject.save! }.to change { Account::User.count }.by(1)
        expect(Account::User.where(account_id: subject.id, role: 'yalty')).to be_exist
      end

      it 'should not create user with yalty role if already exists' do
        create(:account_user, :with_yalty_role, account: subject)
        expect(subject.yalty_access).to be_truthy
        subject.yalty_access = true
        expect(subject.yalty_access).to be_truthy
        expect(subject.changes).to_not include(:yalty_access)
        expect { subject.save! }.to_not change { Account::User.count }
        expect(Account::User.where(account_id: subject.id, role: 'yalty')).to be_exist
      end

      it 'should be able to authenticate user with configured password and email' do
        ENV['YALTY_ACCESS_EMAIL'] = 'access@example.com'
        ENV['YALTY_ACCESS_PASSWORD_DIGEST'] = BCrypt::Password.create('1234567890', cost: 10)

        subject.update!(yalty_access: true)

        user = Account::User.where(account: subject, email: ENV['YALTY_ACCESS_EMAIL']).first!
        expect(user.authenticate('1234567890')).to_not be_falsey
      end

      it 'should send an email to yalty access email' do
        expect(YaltyAccessMailer).to receive_message_chain(:access_enable, :deliver_later)
        expect(subject.yalty_access).to be_falsey
        subject.update!(yalty_access: true)
      end
    end

    describe 'when set to false' do
      let!(:yalty_user) { create(:account_user, :with_yalty_role, account: subject) }

      it 'should destroy user with yalty role if exists' do
        expect(subject.yalty_access).to be_truthy
        subject.yalty_access = false
        expect(subject.yalty_access).to be_falsey
        expect(subject.changes).to include(:yalty_access)
        expect { subject.save! }.to change { Account::User.count }.by(-1)
        expect(Account::User.where(account_id: subject.id, role: 'yalty')).to_not be_exist
      end

      it 'should not destroy user with yalty role if not exists' do
        yalty_user.destroy!
        expect(subject.yalty_access).to be_falsey
        subject.yalty_access = false
        expect(subject.yalty_access).to be_falsey
        expect(subject.changes).to_not include(:yalty_access)
        expect { subject.save! }.to_not change { Account::User.count }
        expect(Account::User.where(account_id: subject.id, role: 'yalty')).to_not be_exist
      end

      it 'should send an email to yalty access email' do
        expect(YaltyAccessMailer).to receive_message_chain(:access_disable, :deliver_later)
        expect(subject.yalty_access).to be_truthy
        subject.update!(yalty_access: false)
      end
    end

    describe 'using with_yalty_access scope' do
      before do
        create_list(:account_user, 2)
        create_list(:account_user, 3, :with_yalty_role)
      end

      it 'should return all accounts with yalty access enable' do
        expect(Account.with_yalty_access.count).to eql(3)
        expect(Account.count).to be > 3
      end
    end
  end

  context '#create_intercom_and_stripe_resources' do
    let(:account) { build(:account) }
    let(:payments_job) { Payments::CreateOrUpdateCustomerWithSubscription }
    let(:intercom_job) { SendDataToIntercom }

    before do
      allow_any_instance_of(Account).to receive(:stripe_enabled?).and_return(true)
      allow(payments_job).to receive(:perform_now)
      allow(intercom_job).to receive(:perform_now)
    end

    it 'invokes both jobs synchoronously' do
      account.save!
      expect(payments_job).to have_received(:perform_now).with(account)
      expect(intercom_job).to have_received(:perform_now).with(account.id, 'Account')
    end
  end

  context 'intercom integration' do
    include_context 'shared_context_intercom_attributes'
    let(:account) { create(:account) }

    it 'is of type :companies' do
      expect(account.intercom_type).to eq(:companies)
    end

    it 'includes proper attributes' do
      expect(account.intercom_attributes).to eq(proper_account_intercom_attributes)
    end

    it 'returns proper data' do
      data_keys = account.intercom_data.keys + account.intercom_data[:custom_attributes].keys
      expect(data_keys).to match_array(proper_account_data_keys)
    end
  end
end
