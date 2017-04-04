require 'rails_helper'

RSpec.describe Payments::CompanyInformation do
  it { is_expected.to be_respond_to(:company_name) }
  it { is_expected.to be_respond_to(:address_1) }
  it { is_expected.to be_respond_to(:address_2) }
  it { is_expected.to be_respond_to(:city) }
  it { is_expected.to be_respond_to(:postalcode) }
  it { is_expected.to be_respond_to(:country) }
  it { is_expected.to be_respond_to(:region) }
end
