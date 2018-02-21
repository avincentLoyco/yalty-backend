require "rails_helper"

RSpec.describe Payments::CreateInvoicePdf do
  let(:card_id) { "card_123" }
  let(:customer) do
    customer = Stripe::Customer.new(id: "cus_123")
    customer.default_source = card_id
    customer.sources = customer_sources
    customer
  end
  let(:customer_sources) do
    card = Stripe::Card.new(id: card_id)
    card.last4 = "4242"
    card.brand = "Visa"
    card.exp_month = 10
    card.exp_year = 2018
    card.name = "Name"
    [card]
  end
  let(:account) { create(:account, customer_id: "cus_123", subscription_id: "sub_123") }
  let(:invoice) { create(:invoice, account: account) }

  subject(:call_service) { described_class.new(invoice).call }

  before { allow(Stripe::Customer).to receive(:retrieve).and_return(customer) }

  context "success" do
    it { expect { call_service }.to change { invoice.generic_file }.from(nil) }

    context "when cards are deleted before" do
      let(:card_id) { nil }
      let(:customer_sources) { [] }
      it { expect { call_service }.to change { invoice.generic_file }.from(nil) }
    end
  end
end
