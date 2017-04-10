require 'rails_helper'
require 'fakeredis/rspec'
require 'sidekiq/testing'

RSpec.describe Payments::StripeEventsHandler do
  include ActiveJob::TestHelper

  let(:customer_id) { 'cus_123' }
  let!(:account) do
    create :account, :with_billing_information, customer_id: customer_id,
      subscription_id: subscription.id
  end

  before { allow(Stripe::Event).to receive(:retrieve).and_return(stripe_event) }

  let(:invoice_id) { 'invoice_123' }
  let(:status) { 'active' }
  let(:subscription) do
    StripeSubscription.new('subscription', 123, invoice_items, status, customer_id, 'subscription')
  end

  let(:stripe_event) do
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
    double(
      id: invoice_id,
      object: 'invoice',
      amount_due: 1234,
      currency: 'chf',
      paid: false,
      date: 1_488_967_394,
      attempt_count: 3,
      next_payment_attempt: 1_490_194_636,
      lines: invoice_items,
      customer: customer_id,
      status: status,
      receipt_number: 1234,
      tax: 0,
      tax_percent: 0,
      starting_balance: 0,
      subtotal: 0,
      total: 0,
      subscription: subscription.id
    )
  end

  let(:invoice_items) do
    stripe_invoice_items = Stripe::ListObject.new
    stripe_invoice_items.object = 'list'
    stripe_invoice_items.data = [invoice_item_free, invoice_item_payed]
    stripe_invoice_items
  end

  let(:invoice_item_free) do
    invoice_item = Stripe::StripeObject.new(id: 'invoice_item1')
    invoice_item.amount = 0
    invoice_item.currency = 'chf'
    invoice_item.object = 'line_item'
    invoice_item.period = { start: 1_488_553_442, end: 1_491_231_842 }
    invoice_item.proration = true
    invoice_item.quantity = 3
    invoice_item.subscription = 'subscription'
    invoice_item.subscription_item = 'subscription_item1'
    invoice_item.type = 'subscription'
    invoice_item.plan = free_plan
    invoice_item
  end

  let(:invoice_item_payed) do
    invoice_item = Stripe::StripeObject.new(id: 'invoice_item2')
    invoice_item.amount = 666
    invoice_item.currency = 'chf'
    invoice_item.object = 'line_item'
    invoice_item.period = { start: 1_488_553_442, end: 1_491_231_842 }
    invoice_item.proration = true
    invoice_item.quantity = 3
    invoice_item.subscription = 'subscription'
    invoice_item.subscription_item = 'subscription_item1'
    invoice_item.type = 'subscription'
    invoice_item.plan = payed_plan
    invoice_item
  end

  let(:free_plan) do
    plan = Stripe::Plan.new(id: 'free-plan')
    plan.name = 'Free Plan'
    plan.amount = 0
    plan.currency = 'chf'
    plan.interval = 'month'
    plan.interval_count = 3
    plan.trial_period_ends = nil
    plan
  end

  let(:payed_plan) do
    plan = Stripe::Plan.new(id: 'payed-plan')
    plan.name = 'Payed Plan'
    plan.amount = 4
    plan.currency = 'chf'
    plan.interval = 'month'
    plan.interval_count = 3
    plan.trial_period_days = nil
    plan
  end

  before { allow(Stripe::Subscription).to receive(:retrieve).and_return(subscription) }

  subject(:job) { described_class.perform_now(stripe_event.id) }

  context 'when event status is invoice.created' do
    let(:event_type) { 'invoice.created' }
    let(:event_object) { invoice }
    it { expect { job }.to change { account.reload.invoices.size }.by 1 }

    context 'change invoice status to pending and does not update receipt_number' do
      before { job }
      it { expect(account.invoices.last.status).to eq('pending') }
      it { expect(account.invoices.last.receipt_number).to eq(nil) }
    end

    context 'should create invoice if not only free-plan is subscribed' do
      it { expect { job }.to change { account.invoices.count } }
    end

    context 'should not create invoice if only free-plan is subscribed' do
      before do
        invoice_items.data = [invoice_item_free]
      end

      it { expect { job }.to_not change { account.invoices.count } }
    end

    context 'should not create invoice if in trial period' do
      before do
        subscription.status = 'trialing'
      end

      it { expect { job }.to_not change { account.invoices.count } }
    end
  end

  context 'when event is invoice.payment_failed' do
    before { account.update(invoices: [existing_invoice]) }
    let(:existing_invoice) { create :invoice }
    let(:event_type) { 'invoice.payment_failed' }
    let(:event_object) { invoice }
    let(:invoice_id) { existing_invoice.invoice_id }

    context 'change invoice status to failed and does not change receipt number' do
      before { job }
      it { expect(account.invoices.find_by(invoice_id: invoice_id).status).to eq('failed') }
      it { expect(account.invoices.last.receipt_number).to eq(nil) }
    end
  end

  context 'when event is invoice.payment_succeeded' do
    before { account.update(invoices: [existing_invoice]) }
    let(:existing_invoice) { create :invoice }
    let(:event_type) { 'invoice.payment_succeeded' }
    let(:event_object) { invoice }
    let(:invoice_id) { existing_invoice.invoice_id }

    context 'change invoice status to success and changes receipt number' do
      before { job }
      it { expect(account.invoices.find_by(invoice_id: invoice_id).status).to eq('success') }
      it { expect(account.invoices.last.reload.receipt_number).not_to eq(nil) }
    end

    xit 'generates pdf file'
  end

  context 'when event is customer.subscription.updated' do
    before { account.update(available_modules: ['filevault']) }
    let(:event_type) { 'customer.subscription.updated' }
    let(:event_object) { subscription }

    context "when status is not 'canceled'" do
      before { job }
      it { expect(account.available_modules).to eq(['filevault']) }
    end

    context "when status is 'canceled'" do
      let(:status) { 'canceled' }
      before { job }
      it { expect(account.reload.available_modules).to eq([]) }
    end
  end
end
