require 'rails_helper'

RSpec.describe Attribute::Currency do
  it { is_expected.to be_respond_to(:currency) }
end
