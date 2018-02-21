require "rails_helper"

RSpec.describe Payments::InvoiceLines do
  it { is_expected.to be_respond_to(:data) }
end
