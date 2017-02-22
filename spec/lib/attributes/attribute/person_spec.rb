require 'rails_helper'

RSpec.describe Attribute::Person do
  it { is_expected.to be_respond_to(:lastname) }
  it { is_expected.to be_respond_to(:firstname) }
  it { is_expected.to be_respond_to(:birthdate) }
  it { is_expected.to be_respond_to(:gender) }
  it { is_expected.to be_respond_to(:nationality) }
  it { is_expected.to be_respond_to(:permit_type) }
  it { is_expected.to be_respond_to(:avs_number) }
  it { is_expected.to be_respond_to(:permit_expiry) }
end
