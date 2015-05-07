require 'rails_helper'

RSpec.describe Account, type: :model do
  it { should have_db_column(:subdomain).with_options(null: false) }
  it { should have_db_index(:subdomain).unique(true) }
  it { should validate_presence_of(:subdomain) }
  it { should validate_uniqueness_of(:subdomain).case_insensitive }
  it { should allow_value('subdomain', 'sub-domain', '123subdomain', 'subdomain-123').for(:subdomain) }
  it { should_not allow_value('-subdomain', 'subdomain-', 'sub domain', 'subdömaìn', 'SubDomain').for(:subdomain) }

  it { should have_db_column(:company_name) }
  it { should validate_presence_of(:company_name) }
end
