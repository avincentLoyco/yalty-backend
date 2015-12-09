require 'rails_helper'

RSpec.describe Account, type: :model do
  subject { build(:account) }

  it { is_expected.to have_db_column(:id).of_type(:uuid) }
  it { is_expected.to have_db_column(:subdomain).with_options(null: false) }
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

  it { is_expected.to have_db_column(:company_name) }
  it { is_expected.to validate_presence_of(:company_name) }

  it { is_expected.to have_many(:working_places) }

  it { is_expected.to have_many(:custom_holidays).through(:holiday_policies) }

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
    it 'should save account with valid timezone name' do
      timezone_name = ActiveSupport::TimeZone.all.last.tzinfo.name
      account = build(:account, timezone: timezone_name)

      expect(account).to be_valid
      expect(account.timezone).to eq(timezone_name)
    end

    it 'should not save account with not valid timezone name' do
      account = build(:account, timezone: 'ABC')

      expect(account).to_not be_valid
    end
  end
end
