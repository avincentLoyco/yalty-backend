require 'rails_helper'

RSpec.describe Attribute::Boolean do
  it { is_expected.to be_respond_to(:boolean) }
end
