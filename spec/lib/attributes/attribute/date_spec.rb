require 'rails_helper'

RSpec.describe Attribute::Date do
  it { is_expected.to be_respond_to(:date) }
  it { is_expected.to validate_presence_of(:date) }
end
