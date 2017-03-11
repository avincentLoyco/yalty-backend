require 'rails_helper'
require 'fakeredis/rspec'
require 'sidekiq/testing'
require 'rake'

RSpec.describe 'create_customers_for_existing_accounts', type: :rake do
  include_context 'rake'

  let!(:account)  { create(:account, customer_id: 'cus_123', subscription_id: 'sub_123') }
  let!(:accounts) { create_list(:account, 3) }

  subject { rake['payments:create_customers_for_existing_accounts'].invoke }

  context 'in case of success' do
    let(:customer)     { StripeCustomer.new(SecureRandom.hex) }
    let(:subscription) { StripeSubscription.new(SecureRandom.hex) }

    before do
      allow(Stripe::Customer).to receive(:create).and_return(customer)
      allow(Stripe::Subscription).to receive(:create).and_return(subscription)
    end

    context 'when customer and subscription does not exist' do
      it { expect { subject }.to change { Account.pluck(:customer_id).compact.size }.from(1).to(4) }
      it { expect { subject }.to change { Account.pluck(:subscription_id).compact.size }.from(1).to(4) }
    end

    context 'when subscription_id is nil' do
      before { account.update!(subscription_id: nil) }

      it { expect { subject }.to change { Account.pluck(:customer_id).compact.size }.from(1).to(4) }
      it { expect { subject }.to change { Account.pluck(:subscription_id).compact.size }.from(0).to(4) }
    end
  end

  context 'in case of failure' do
    let(:customer)     { StripeCustomer.new(SecureRandom.hex) }
    let(:subscription) { StripeSubscription.new(SecureRandom.hex) }

    context 'when Striper::Customer fails' do
      before do
        allow(Stripe::Customer).to receive(:create).and_raise(Stripe::APIError)
        allow(Stripe::Subscription).to receive(:create).and_return(subscription)
      end

      it { expect { subject }.to_not change { Account.pluck(:customer_id).compact.size } }
      it { expect { subject }.to_not change { Account.pluck(:subscription_id).compact.size } }
    end

    context 'when Stripe::Subscription fails' do
      before do
        allow(Stripe::Customer).to receive(:create).and_return(customer)
        allow(Stripe::Subscription).to receive(:create).and_raise(Stripe::APIError)
      end

      it { expect { subject }.to change { Account.pluck(:customer_id).compact.size }.from(1).to(4) }
      it { expect { subject }.to_not change { Account.pluck(:subscription_id).compact.size } }
    end
  end
end
