require "rails_helper"

RSpec.describe Attribute::Currency do
  it { is_expected.to be_respond_to(:amount) }
  it { is_expected.to be_respond_to(:isocode) }
end
