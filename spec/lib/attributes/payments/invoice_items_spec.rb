require 'rails_helper'

RSpec.describe Payments::InvoiceItems do
  it { is_expected.to be_respond_to(:data) }
end
