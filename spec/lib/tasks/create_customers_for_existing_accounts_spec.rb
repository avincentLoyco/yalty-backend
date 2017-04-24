require 'rails_helper'
require 'rake'

RSpec.describe 'payments:create_customers_for_existing_accounts', type: :rake do
  include_context 'rake'

  let!(:account)  { create(:account, customer_id: 'cus_123', subscription_id: 'sub_123') }
  let!(:accounts) { create_list(:account, 3, customer_id: nil, subscription_id: nil) }

  context 'in case of success' do
    let(:customer)     { StripeCustomer.new(SecureRandom.hex) }
    let(:subscription) { StripeSubscription.new(SecureRandom.hex) }

    before do
      allow(Stripe::Customer).to receive(:create).and_return(customer)
      allow(Stripe::Customer).to receive(:retrieve).and_return(customer)
      allow(Stripe::Subscription).to receive(:create).and_return(subscription)
      allow(Stripe::Subscription).to receive(:retrieve).and_return(subscription)
    end

    context 'when customer and subscription does not exist' do
      it { expect { subject }.to change { Account.where('customer_id IS NOT NULL').count }.from(1).to(4) }
      it { expect { subject }.to change { Account.where('subscription_id IS NOT NULL').count }.from(1).to(4) }
    end

    context 'when subscription_id is nil' do
      before { account.update!(subscription_id: nil) }

      it { expect { subject }.to change { Account.where('customer_id IS NOT NULL').count }.from(1).to(4) }
      it { expect { subject }.to change { Account.where('subscription_id IS NOT NULL').count }.from(0).to(4) }
    end
  end
end
