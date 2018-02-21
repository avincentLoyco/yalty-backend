require "rails_helper"

RSpec.describe Payments::Plan do
  it { is_expected.to be_respond_to(:id) }
  it { is_expected.to be_respond_to(:name) }
  it { is_expected.to be_respond_to(:amount) }
  it { is_expected.to be_respond_to(:currency) }
  it { is_expected.to be_respond_to(:interval) }
  it { is_expected.to be_respond_to(:interval_count) }
end
