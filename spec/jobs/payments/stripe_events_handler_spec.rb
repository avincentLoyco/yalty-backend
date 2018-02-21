require "rails_helper"

RSpec.describe Payments::StripeEventsHandler, type: :job do
  let(:customer_id) { "cus_123" }
  let!(:account) do
    create :account, :with_billing_information, customer_id: customer_id,
      subscription_id: subscription.id
  end

  let(:invoice_id) { "invoice_123" }
  let(:status) { "active" }
  let(:subscription) do
    StripeSubscription.new("subscription", 123, invoice_items, status, customer_id, "subscription")
  end

  let(:stripe_event) do
    stripe_event = Stripe::Event.new(id: "ev_123")
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
      object: "invoice",
      amount_due: 1234,
      currency: "chf",
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
      subscription: subscription.id,
      charge: "charge_id",
      period_start: Time.zone.now.to_i,
      period_end: 1.month.from_now.to_i
    )
  end

  let(:invoice_items) do
    stripe_invoice_items = Stripe::ListObject.new
    stripe_invoice_items.object = "list"
    stripe_invoice_items.has_more = false
    stripe_invoice_items.data = [invoice_item_free, invoice_item_payed]
    stripe_invoice_items
  end

  let(:invoice_item_free) do
    invoice_item = Stripe::StripeObject.new(id: "invoice_item1")
    invoice_item.amount = 0
    invoice_item.currency = "chf"
    invoice_item.object = "line_item"
    invoice_item.period = { start: 1_488_553_442, end: 1_491_231_842 }
    invoice_item.proration = true
    invoice_item.quantity = 3
    invoice_item.subscription = "subscription"
    invoice_item.subscription_item = "subscription_item1"
    invoice_item.type = "subscription"
    invoice_item.plan = free_plan
    invoice_item
  end

  let(:invoice_item_payed) do
    invoice_item = Stripe::StripeObject.new(id: "invoice_item2")
    invoice_item.amount = 666
    invoice_item.currency = "chf"
    invoice_item.object = "line_item"
    invoice_item.period = { start: 1_488_553_442, end: 1_491_231_842 }
    invoice_item.proration = true
    invoice_item.quantity = 3
    invoice_item.subscription = "subscription"
    invoice_item.subscription_item = "subscription_item1"
    invoice_item.type = "subscription"
    invoice_item.plan = payed_plan
    invoice_item
  end

  let(:free_plan) do
    plan = Stripe::Plan.new(id: "free-plan")
    plan.name = "Free Plan"
    plan.amount = 0
    plan.currency = "chf"
    plan.interval = "month"
    plan.interval_count = 3
    plan.trial_period_ends = nil
    plan
  end

  let(:payed_plan) do
    plan = Stripe::Plan.new(id: "payed-plan")
    plan.name = "Payed Plan"
    plan.amount = 4
    plan.currency = "chf"
    plan.interval = "month"
    plan.interval_count = 3
    plan.trial_period_days = nil
    plan
  end

  before do
    allow(Stripe::Event).to receive(:retrieve).and_return(stripe_event)
    allow(Stripe::Subscription).to receive(:create).and_return(subscription)
    allow(Stripe::Subscription).to receive(:retrieve).and_return(subscription)
    modules = [
      ::Payments::PlanModule.new(id: "filevault", canceled: false),
      ::Payments::PlanModule.new(id: "exports", canceled: true)
    ]
    account.update(available_modules: ::Payments::AvailableModules.new(data: modules))
    allow(::Payments::CreateInvoicePdf).to receive_message_chain(:new, :call)
    allow(PaymentsMailer).to receive_message_chain(:subscription_canceled, :deliver_now)
    allow(PaymentsMailer).to receive_message_chain(:payment_succeeded, :deliver_now)
    allow(PaymentsMailer).to receive_message_chain(:payment_failed, :deliver_now)
  end

  shared_examples "not creating invoice with free-plan only" do
    before { invoice_items.data = [invoice_item_free] }

    it { expect { job }.to_not change { account.invoices.count } }
    it { expect { job }.to_not change { account.available_modules.size } }

    context "does not invoke any other serivces" do
      before { job }

      it { expect(PaymentsMailer).to_not have_received(:payment_succeeded) }
      it { expect(PaymentsMailer).to_not have_received(:payment_failed) }
      it { expect(::Payments::CreateInvoicePdf).to_not have_received(:new) }
    end
  end

  subject(:job) { described_class.perform_now(stripe_event.id) }

  context "when event status is invoice.created" do
    let(:event_type) { "invoice.created" }
    let(:event_object) { invoice }

    context "change invoice status to pending and does not update receipt_number" do
      before { job }
      it { expect(account.invoices.last.status).to eq("pending") }
      it { expect(account.invoices.last.receipt_number).to eq(nil) }
    end

    context "should create invoice if not only free-plan is subscribed" do
      it { expect { job }.to change { account.reload.invoices.size }.by 1 }
    end

    it_behaves_like "not creating invoice with free-plan only"

    context "should not create invoice if in trial period" do
      before { subscription.status = "trialing" }

      it { expect { job }.to_not change { account.invoices.count } }
    end

    context "should not create invoice if plan is canceled" do
      before do
        modules = [::Payments::PlanModule.new(id: payed_plan.id, canceled: true)]
        account.update!(available_modules: ::Payments::AvailableModules.new(data: modules))
      end

      it { expect { job }.to_not change { account.invoices.count } }
    end

    context "should not create invoice if plan is free" do
      before do
        modules = [::Payments::PlanModule.new(id: payed_plan.id, canceled: false, free: true)]
        account.update!(available_modules: ::Payments::AvailableModules.new(data: modules))
      end

      it { expect { job }.to_not change { account.invoices.count } }
    end

    context "remove canceled plans from available_modules" do
      before do
        account.available_modules.add(id: "premium", canceled: true, free: true)
        account.save!
      end

      it { expect { job }.to change { account.reload.available_modules.size }.from(3).to(2) }

      it "removes only canceled jobs" do
        job
        expect(account.reload.available_modules.all).to match_array(%w(filevault premium))
      end
    end

    context "but invoice was created already" do
      let(:existing_invoice) { create(:invoice, invoice_id: event_object.id) }

      before { account.update(invoices: [existing_invoice]) }

      it { expect { job }.to_not change { Invoice.count } }
      it { expect { job }.to change { account.reload.available_modules.size }.from(2).to(1) }
    end
  end

  context "when event is invoice.payment_failed" do
    let(:event_type) { "invoice.payment_failed" }
    let(:event_object) { invoice }
    let(:existing_invoice) { create(:invoice, invoice_id: event_object.id) }
    let(:account_invoice) { account.invoices.find_by(invoice_id: event_object.id) }

    shared_examples "failed status and unchanged receipt_number" do
      before { job }

      it { expect(account_invoice.status).to eq("failed") }
      it { expect(account_invoice.receipt_number).to eq(nil) }
    end

    shared_examples "email is sent" do
      before { job }

      it { expect(PaymentsMailer).to have_received(:payment_failed).with(account_invoice.id).once }
    end

    context "invoice was created before" do
      before { account.update(invoices: [existing_invoice]) }

      it_behaves_like "failed status and unchanged receipt_number"
      it_behaves_like "email is sent"
    end

    context "invoice was not created yet" do
      it { expect { job }.to change { Invoice.count }.by(1) }
      it_behaves_like "failed status and unchanged receipt_number"
      it_behaves_like "email is sent"
      it_behaves_like "not creating invoice with free-plan only"
    end
  end

  context "when event is invoice.payment_succeeded" do
    let(:event_type) { "invoice.payment_succeeded" }
    let(:event_object) { invoice }
    let(:existing_invoice) { create(:invoice, invoice_id: event_object.id) }
    let(:account_invoice) { account.invoices.find_by(invoice_id: event_object.id) }

    shared_examples "success status and updated receipt_number" do
      before { job }

      it { expect(account_invoice.status).to eq("success") }
      it { expect(account_invoice.receipt_number).to_not eq(nil) }
    end

    shared_examples "pdf is generated and emails is sent" do
      before { job }

      it { expect(::Payments::CreateInvoicePdf).to have_received(:new).with(account_invoice) }
      it { expect(PaymentsMailer).to have_received(:payment_succeeded).with(account_invoice.id).once }
    end

    context "invoice was created before" do
      before { account.update(invoices: [existing_invoice]) }

      it_behaves_like "success status and updated receipt_number"
      it_behaves_like "pdf is generated and emails is sent"
    end

    context "invoice was not created yet" do
      it { expect { job }.to change { Invoice.count }.by(1) }
      it_behaves_like "success status and updated receipt_number"
      it_behaves_like "pdf is generated and emails is sent"
      it_behaves_like "not creating invoice with free-plan only"
    end
  end

  context "when event is customer.subscription.updated" do
    let(:event_type) { "customer.subscription.updated" }
    let(:event_object) { subscription }

    context "when status is not 'canceled'" do
      before { job }
      it { expect(account.reload.available_modules.all).to match_array(["filevault", "exports"]) }
      it { expect(PaymentsMailer).to_not have_received(:subscription_canceled) }
      it { expect(Stripe::Subscription).to_not have_received(:create) }
    end

    context "when status is 'canceled'" do
      let(:status) { "canceled" }

      before do
        account.available_modules.add(id: "premium", canceled: true, free: true)
        account.save!
      end

      it "clears modules" do
        expect { job }
          .to change { account.reload.available_modules.actives }
          .from(%w(filevault premium))
          .to(["premium"])
      end

      it "sends email" do
        expect(PaymentsMailer).to receive(:subscription_canceled).with(account.id).once
        job
      end
    end
  end
end
