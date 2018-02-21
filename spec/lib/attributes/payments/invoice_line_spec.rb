require "rails_helper"

RSpec.describe Payments::InvoiceLine do
  it { is_expected.to be_respond_to(:id) }
  it { is_expected.to be_respond_to(:amount) }
  it { is_expected.to be_respond_to(:currency) }
  it { is_expected.to be_respond_to(:period_start) }
  it { is_expected.to be_respond_to(:period_end) }
  it { is_expected.to be_respond_to(:proration) }
  it { is_expected.to be_respond_to(:quantity) }
  it { is_expected.to be_respond_to(:subscription) }
  it { is_expected.to be_respond_to(:subscription_item) }
  it { is_expected.to be_respond_to(:type) }
  it { is_expected.to be_respond_to(:plan) }
end
