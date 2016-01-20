require 'rails_helper'

RSpec.describe Attribute::Number do
  it { is_expected.to be_respond_to(:number) }
end
