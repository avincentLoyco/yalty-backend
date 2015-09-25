require 'rails_helper'

RSpec.describe Attribute::String do
  it { is_expected.to be_respond_to(:string) }
end
