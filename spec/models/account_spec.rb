require 'rails_helper'

RSpec.describe Account, type: :model do
  subject { FactoryGirl.build(:account) }

  it { should have_db_column(:subdomain).with_options(null: false) }
  it { should have_db_index(:subdomain).unique(true) }
  it { should validate_presence_of(:subdomain).on(:update) }
  it { should validate_uniqueness_of(:subdomain).case_insensitive }
  it { should validate_length_of(:subdomain).is_at_most(63) }
  it { should allow_value('a', 'subdomain', 'sub-domain', '123subdomain', 'subdomain-123').for(:subdomain) }
  it { should_not allow_value('-subdomain', 'subdomain-', 'sub domain', 'subdömaìn', 'SubDomain').for(:subdomain) }
  it { should validate_exclusion_of(:subdomain).in_array(['www', 'staging']) }

  context 'generate subdomain from company name on create' do

    it 'should not be blank' do
      account = FactoryGirl.build(:account, subdomain: nil, company_name: 'Company')

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
        account = FactoryGirl.build(:account, subdomain: nil, company_name: company_name)

        expect(account).to be_valid
        expect(account.subdomain).to eql(subdomain)
      end

    end

    it 'must be unique' do
      FactoryGirl.create(:account, subdomain: nil, company_name: 'The Company')
      account = FactoryGirl.build(:account, subdomain: nil, company_name: 'The Company')

      expect(account).to be_valid
      expect(account.subdomain).to match(/\Athe-company-[0-9]+\z/)
    end

  end

  it { should have_db_column(:company_name) }
  it { should validate_presence_of(:company_name) }

  it { should have_many(:users).class_name('Account::User').inverse_of(:account) }

  it { should have_many(:employees).inverse_of(:account) }

  it { is_expected.to have_many(:employee_attributes).class_name('Employee::AttributeDefinition').inverse_of(:account) }
end
