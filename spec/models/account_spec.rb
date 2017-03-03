require 'rails_helper'

RSpec.describe Account, type: :model do
  subject { build(:account, subdomain: 'subdomain') }

  it { is_expected.to have_db_column(:id).of_type(:uuid) }
  it { is_expected.to have_db_column(:customer_id).of_type(:string) }
  it { is_expected.to have_db_column(:available_modules).of_type(:text) }
  it { is_expected.to have_db_column(:subscription_renewal_date).of_type(:date) }
  it { is_expected.to have_db_column(:subdomain).with_options(null: false) }
  it { is_expected.to have_db_column(:invoice_company_info).of_type(:hstore) }
  it { is_expected.to have_db_column(:invoice_emails).of_type(:text) }
  it { is_expected.to have_db_index(:subdomain).unique(true) }
  it { is_expected.to validate_presence_of(:subdomain).on(:update) }
  it { is_expected.to validate_uniqueness_of(:subdomain).case_insensitive }
  it { is_expected.to validate_length_of(:subdomain).is_at_most(63) }
  it { is_expected.to allow_value('a', 'subdomain', 'sub-domain', '123subdomain', 'subdomain-123').for(:subdomain) }
  it { is_expected.to_not allow_value('-subdomain', 'subdomain-', 'sub domain', 'subdömaìn', 'SubDomain').for(:subdomain) }
  it { is_expected.to validate_exclusion_of(:subdomain).in_array(['www', 'staging']) }

  it { is_expected.to have_many(:employee_events).through(:employees) }
  it { is_expected.to have_many(:employee_attribute_versions).through(:employees) }
  it { is_expected.to have_many(:presence_policies) }
  it { is_expected.to have_many(:time_off_categories) }
  it { is_expected.to have_one(:registration_key) }

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
        expect(attr.validation).to eq({ 'presence' => 'true' })
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

  it { is_expected.to have_db_column(:company_name) }
  it { is_expected.to validate_presence_of(:company_name) }

  it { is_expected.to have_many(:working_places) }

  it { is_expected.to have_many(:users).class_name('Account::User').inverse_of(:account) }

  it { is_expected.to have_many(:employees).inverse_of(:account) }

  it { is_expected.to have_many(:employee_attribute_definitions).class_name('Employee::AttributeDefinition').inverse_of(:account) }

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

  describe 'intercom integration' do
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

  describe 'referred_by' do
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
    let(:employee_files) { create_list(:employee_file, 3, :with_jpg) }
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

  describe 'reset resources' do
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

  describe 'stripe callbacks' do
    let(:customer) { StripeCustomer.new('cus123', 'Some description') }
    let(:subscription) { StripeSubscription.new('sub_123') }

    before do
      allow_any_instance_of(Account).to receive(:stripe_enabled?).and_return(true)
      allow(Stripe::Customer).to receive(:retrieve).and_return(customer)
      allow(Stripe::Customer).to receive(:create).and_return(customer)
      allow(Stripe::Subscription).to receive(:create).and_return(subscription)
    end

    context 'create_stripe_customer_with_subscription' do
      let(:account) { build(:account) }

      subject { account.save! }

      it 'triggers creation method' do
        expect(account).to receive(:create_stripe_customer_with_subscription)
        subject
      end

      it 'triggers cration job' do
        expect(Payments::CreateCustomerWithSubscription).to receive(:perform_now).with(account)
        subject
      end
    end

    context 'update_stripe_customer_description' do
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
  end
end
