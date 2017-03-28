require 'rails_helper'
require 'fakeredis/rspec'
require 'sidekiq/testing'

RSpec.describe Payments::StripeEventsHandler do
  include ActiveJob::TestHelper

  before { Account.current = account }

  let(:account) { create :account, :with_billing_information }
  let(:invoice_id) { 'invoice_123' }

  let(:event) do
    stripe_event = Stripe::Event.new(id: 'ev_123')
    stripe_event.type = event_type
    stripe_event.data = object
    stripe_event
  end

  let(:object) do
    stripe_object = Stripe::StripeObject.new
    stripe_object.object = event_object
    stripe_object
  end

  let(:invoice) do
    stripe_invoice = Stripe::Invoice.new(id: invoice_id)
    stripe_invoice.object = 'invoice'
    stripe_invoice.amount_due = 1234
    stripe_invoice.currency = 'chf'
    stripe_invoice.paid = false
    stripe_invoice.date = 1_488_967_394
    stripe_invoice.attempt_count = 3
    stripe_invoice.next_payment_attempt = 1_490_194_636
    stripe_invoice.lines = list_object
    stripe_invoice
  end

  let(:list_object) do
    stripe_list_object = Stripe::ListObject.new
    stripe_list_object.object = 'list'
    stripe_list_object.data = [invoice_item]
    stripe_list_object
  end

  let(:invoice_item) do
    invoice_item = Stripe::StripeObject.new(id: 'invoice_item1')
    invoice_item.amount = 666
    invoice_item.currency = 'chf'
    invoice_item.object = 'line_item'
    invoice_item.period = { start: 1_488_553_442, end: 1_491_231_842 }
    invoice_item.proration = true
    invoice_item.quantity = 3
    invoice_item.subscription = 'subscription'
    invoice_item.subscription_item = 'subscription_item1'
    invoice_item.type = 'subscription'
    invoice_item.plan = plan
    invoice_item
  end

  let(:plan) do
    plan = Stripe::Plan.new(id: 'first_plan')
    plan.name = 'First Plan'
    plan.amount = 4
    plan.currency = 'chf'
    plan.interval = 'month'
    plan.interval_count = 3
    plan
  end

  subject(:job) { described_class.perform_now(event) }

  context 'when event status is invoice.created' do
    let(:event_type) { 'invoice.created' }
    let(:event_object) { invoice }
    it { expect { job }.to change { Account.current.invoices.size }.by 1 }

    context 'change invoice status to pending' do
      before { job }
      it { expect(Account.current.invoices.last.status).to eq('pending') }
    end
  end

  context 'when event is invoice.payment_failed' do
    let(:existing_invoice) { create :invoice, account: Account.current }
    let(:event_type) { 'invoice.payment_failed' }
    let(:event_object) { invoice }
    let(:invoice_id) { existing_invoice.invoice_id }

    context 'change invoice status to failed' do
      before { job }
      it { expect(Account.current.invoices.find_by(invoice_id: invoice_id).status).to eq('failed') }
    end
  end

  context 'when event is invoice.payment_succeeded' do
    let(:existing_invoice) { create :invoice, account: Account.current }
    let(:event_type) { 'invoice.payment_succeeded' }
    let(:event_object) { invoice }
    let(:invoice_id) { existing_invoice.invoice_id }

    context 'change invoice status to success' do
      before { job }
      it { expect(Account.current.invoices.find_by(invoice_id: invoice_id).status).to eq('success') }
    end

    it 'generates pdf file'
  end

  context 'when event is customer.subscription.updated' do
    before { Account.current.update(available_modules: ['filevault']) }
    let(:event_type) { 'customer.subscription.updated' }
    let(:event_object) { subscription }

    let(:subscription) do
      subscription = Stripe::Subscription.new(id: 'subscription')
      subscription.status = status
      subscription
    end

    context "when status is not 'canceled'" do
      let(:status) { 'active' }
      before { job }
      it { expect(Account.current.available_modules).to eq(['filevault']) }
    end

    context "when status is 'canceled'" do
      let(:status) { 'canceled' }
      before { job }
      it { expect(Account.current.available_modules).to eq([]) }
    end
  end
end
