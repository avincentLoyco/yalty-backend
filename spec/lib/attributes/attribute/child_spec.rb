require 'rails_helper'

RSpec.describe Attribute::Child do
  it { is_expected.to be_respond_to(:mother_is_working) }
  it { is_expected.to be_respond_to(:is_student) }
  it { is_expected.to be_respond_to(:lastname) }
  it { is_expected.to be_respond_to(:firstname) }
  it { is_expected.to be_respond_to(:birthdate) }
  it { is_expected.to be_respond_to(:gender) }
end
