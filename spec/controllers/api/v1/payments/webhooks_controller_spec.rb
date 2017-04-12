require 'rails_helper'

RSpec.describe API::V1::Payments::WebhooksController, type: :controller do
  include_context 'shared_context_headers'

  let(:customer_id) { 'cus_123' }
  let(:event_type) { 'invoice.created' }
  let!(:account) { create(:account, customer_id: customer_id, subscription_id: 'sub_123') }

  let(:event) do
    event = Stripe::Event.new(id: 'ev_123')
    event.type = event_type
    event.data = event_object
    event
  end

  let(:event_object) do
    stripe_object = Stripe::StripeObject.new
    stripe_object.object = double(customer: customer_id, lines: invoice_items)
    stripe_object
  end

  let(:invoice_items) do
    stripe_invoice_items = Stripe::ListObject.new
    stripe_invoice_items.object = 'list'
    stripe_invoice_items.data = [filevault_invoice_item, exports_invoice_item]
    stripe_invoice_items
  end

  let(:filevault_invoice_item) do
    invoice_item = Stripe::InvoiceItem.new(id: 'ii_123')
    invoice_item.plan = Stripe::Plan.new(id: 'filevault')
    invoice_item
  end

  let(:exports_invoice_item) do
    invoice_item = Stripe::InvoiceItem.new(id: 'ii_456')
    invoice_item.plan = Stripe::Plan.new(id: 'exports')
    invoice_item
  end

  let(:subscription_items) do
    stripe_subscription_items = Stripe::ListObject.new
    stripe_subscription_items.object = 'list'
    stripe_subscription_items.data = [filevault_subscription_item, exports_subscription_item]
    stripe_subscription_items
  end

  let(:filevault_subscription_item) do
    subscription_item = Stripe::SubscriptionItem.new(id: 'si_123')
    subscription_item.plan = Stripe::Plan.new(id: 'filevault')
    subscription_item
  end

  let(:exports_subscription_item) do
    subscription_item = Stripe::SubscriptionItem.new(id: 'si_456')
    subscription_item.plan = Stripe::Plan.new(id: 'exports')
    subscription_item
  end

  subject(:send_webhook) { post :webhook, { id: event.id }, @env }

  before do
    allow(::Payments::StripeEventsHandler).to receive(:perform_later)
    allow(Stripe::Event).to receive(:retrieve).and_return(event)
    allow(Stripe::SubscriptionItem).to receive(:list).and_return(subscription_items)
    allow_any_instance_of(Stripe::SubscriptionItem).to receive(:delete)
    basic_http_login('whatever', ENV['STRIPE_WEBHOOK_PASSWORD'])
  end

  context 'success' do
    shared_examples_for 'event retrieved and job scheduled' do
      it { is_expected.to have_http_status(200) }
      it 'runs the StripeEventsHandler job' do
        expect(::Payments::StripeEventsHandler).to receive(:perform_later).with(event.id)
        send_webhook
      end
    end

    context 'event is not invoice.created' do
      let(:event_type) { 'customer.subscription.updated' }

      it_should_behave_like 'event retrieved and job scheduled'

      it 'should not fetch SubscriptionItem list' do
        expect(Stripe::SubscriptionItem).to_not receive(:list)
        send_webhook
      end
    end

    context 'event type is invoice.created' do
      context 'there are no available_modules' do
        it_should_behave_like 'event retrieved and job scheduled'

        it 'should not fetch SubscriptionItem list' do
          expect(Stripe::SubscriptionItem).to_not receive(:list)
          send_webhook
        end
      end

      context 'there are available_modules but none is canceled' do
        before do
          modules = [::Payments::PlanModule.new(id: 'filevault', canceled: false)]
          account.update!(available_modules: ::Payments::AvailableModules.new(data: modules))
        end

        it_should_behave_like 'event retrieved and job scheduled'

        it 'should not fetch SubscriptionItem list' do
          expect(Stripe::SubscriptionItem).to_not receive(:list)
          send_webhook
        end
      end

      context 'there are canceled_modules' do
        before do
          modules = [
            ::Payments::PlanModule.new(id: 'filevault', canceled: false),
            ::Payments::PlanModule.new(id: 'exports', canceled: true)
          ]
          account.update!(available_modules: ::Payments::AvailableModules.new(data: modules))
        end

        it_should_behave_like 'event retrieved and job scheduled'

        it 'should fetch SubscriptionItem list' do
          expect(Stripe::SubscriptionItem).to receive(:list)
          send_webhook
        end

        it 'should remove canceled subscription item' do
          expect(exports_subscription_item).to receive(:delete)
          send_webhook
        end

        it 'should not remove active subscription item' do
          expect(filevault_subscription_item).to_not receive(:delete)
          send_webhook
        end
      end
    end
  end

  context 'errors' do
    context 'basic auth fails' do
      before { basic_http_login('whatever', 'wrong password') }

      it { is_expected.to have_http_status(401) }
    end

    context 'fetching Event fails' do
      before { allow(Stripe::Event).to receive(:retrieve).and_raise(Stripe::APIError) }

      it { is_expected.to have_http_status(502) }
    end

    context 'no account with customer_id' do
      before { account.update!(customer_id: nil) }

      it { is_expected.to have_http_status(404) }
    end

    context 'Stripe::SubscriptionItem.list fails' do
      before do
        modules = [::Payments::PlanModule.new(id: 'exports', canceled: true)]
        account.update!(available_modules: ::Payments::AvailableModules.new(data: modules))
        allow(Stripe::SubscriptionItem).to receive(:list).and_raise(Stripe::APIError)
      end

      it { is_expected.to have_http_status(502) }
    end
  end
end
