require 'rails_helper'

RSpec.describe Attribute::String do
  it { is_expected.to be_respond_to(:string) }
  it { is_expected.to validate_presence_of(:string) }
end
