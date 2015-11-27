require 'rails_helper'

RSpec.describe Attribute::Address do
  it { is_expected.to be_respond_to(:street) }
  it { is_expected.to be_respond_to(:streetno) }
  it { is_expected.to be_respond_to(:postalcode) }
  it { is_expected.to be_respond_to(:city) }
  it { is_expected.to be_respond_to(:region) }
  it { is_expected.to be_respond_to(:country) }
end
