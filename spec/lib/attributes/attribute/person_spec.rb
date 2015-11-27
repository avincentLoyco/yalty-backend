require 'rails_helper'

RSpec.describe Attribute::Person do
  it { is_expected.to be_respond_to(:lastname) }
  it { is_expected.to be_respond_to(:firstname) }
  it { is_expected.to be_respond_to(:birthdate) }
  it { is_expected.to be_respond_to(:gender) }
end
