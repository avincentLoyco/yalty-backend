require 'rails_helper'

RSpec.describe API::V1::Payments::SubscriptionsController, type: :controller do
  include_context 'shared_context_headers'
  include_context 'shared_context_timecop_helper'

  let!(:timestamp)   { Time.zone.now.to_i }
  let(:customer)     { StripeCustomer.new('cus_123') }
  let(:subscription) { StripeSubscription.new('sub_123', timestamp, 5) }
  let(:invoice)      { StripeInvoice.new('in_123', 666, timestamp) }
  let(:plans) do
    ['master-plan', 'evil-plan', 'sweet-sweet-plan'].map do |plan_id|
      StripePlan.new(plan_id, 400, 'chf', 'month', plan_id.titleize)
    end
  end
  let(:subscription_items) do
    [StripeSubscriptionItem.new('si_123', plans.first)]
  end

  before do
    Account.current.update(customer_id: customer.id, subscription_id: subscription.id)
    Account::User.current.update(role: 'account_owner')

    allow(Stripe::Invoice).to receive(:upcoming).and_return(invoice)
    allow(Stripe::Subscription).to receive(:retrieve).and_return(subscription)
    allow(Stripe::Plan).to receive_message_chain(:list, :data).and_return(plans)
    allow(Stripe::SubscriptionItem).to receive_message_chain(:list, :data).and_return(subscription_items)
    allow_any_instance_of(StripeInvoice).to receive_message_chain(:lines, :data).and_return([])
  end

  describe '#GET /v1/payments/subscription' do
    let(:expected_json) do
      {
        id: subscription.id,
        current_period_end: '2016-01-01T00:00:00.000Z',
        quantity: subscription.quantity,
        plans: [
          {
            id: plans.first.id,
            amount: plans.first.amount,
            currency: plans.first.currency,
            interval: plans.first.interval,
            name: plans.first.name,
            active: true
          },
          {
            id: plans.second.id,
            amount: plans.second.amount,
            currency: plans.second.currency,
            interval: plans.second.interval,
            name: plans.second.name,
            active: false
          },
          {
            id: plans.third.id,
            amount: plans.third.amount,
            currency: plans.third.currency,
            interval: plans.third.interval,
            name: plans.third.name,
            active: false
          }
        ],
        invoice: {
          id: invoice.id,
          amount_due: invoice.amount_due,
          date: '2016-01-01T00:00:00.000Z',
          prorate_amount: 0,
          line_items: []
        }
      }
    end

    subject(:get_subscription) { get :index  }

    context 'when user is an account_owner' do
      before { get_subscription }

      it { expect(response.status).to eq(200) }
      it { expect_json(expected_json) }
    end

    context 'when user is not an account_owner but' do
      context 'an account_administrator' do
        before do
          Account::User.current.update!(role: 'account_administrator')
          get_subscription
        end

        it { expect(response.status).to eq(403) }
      end

      context 'a regular user' do
        before do
          Account::User.current.update(role: 'user')
          get_subscription
        end

        it { expect(response.status).to eq(403) }
      end
    end
  end
end
