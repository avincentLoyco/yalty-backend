require 'rails_helper'
require 'fakeredis/rspec'
require 'sidekiq/testing'

RSpec.describe CreateCustomerWithSubscription, type: :job do
  include ActiveJob::TestHelper
  StripeCustomer = Struct.new(:id)
  StripeSubscription = Struct.new(:id)

  let!(:account) { create(:account) }

  subject(:job) { described_class.perform_now(account) }

  before { allow_any_instance_of(Account).to receive(:stripe_enabled?).and_return(true) }

  context 'in case of success' do
    before do
      allow(Stripe::Customer).to receive(:create).and_return(customer)
      allow(Stripe::Subscription).to receive(:create).and_return(subscription)
    end

    let(:customer) { StripeCustomer.new('cus_123') }
    let(:subscription) { StripeSubscription.new('sub_123') }

    context 'when customer does not exist' do
      it { expect { job }.to change(account, :customer_id).from(nil).to('cus_123') }
      it { expect { job }.to change(account, :subscription_id).from(nil).to('sub_123') }
    end

    context 'when customer exists' do
      let!(:account) { create(:account, customer_id: 'cus_456') }

      it { expect { job }.to_not change(account, :customer_id) }
      it { expect { job }.to change(account, :subscription_id).from(nil).to('sub_123') }
    end

    context 'when customer_id is nil' do
      let(:customer) { StripeCustomer.new(nil) }

      it { expect { job }.to_not change(account, :customer_id) }
      it { expect { job }.to_not change(account, :subscription_id) }
    end
  end

  context 'in case of error' do
    context 'when Stripe::Customer raises error' do
      before { allow(Stripe::Customer).to receive(:create).and_raise(Stripe::APIError) }

      it { expect { job }.to change(enqueued_jobs, :size).by(1) }
      it { expect { job }.to_not change(account, :customer_id) }
      it { expect { job }.to_not change(account, :subscription_id) }
    end

    context 'when Stripe::Subscription raises error' do
      before do
        allow(Stripe::Customer).to receive(:create).and_return(customer)
        allow(Stripe::Subscription).to receive(:create).and_raise(Stripe::APIError)
      end

      let(:customer) { StripeCustomer.new('cus_123') }

      context 'when customer_id is nil' do
        it { expect { job }.to change(enqueued_jobs, :size).by(1) }
        it { expect { job }.to change { account.reload.customer_id }.from(nil).to('cus_123') }
        it { expect { job }.to_not change(account, :subscription_id) }
      end

      context 'when customer_id exists' do
        let!(:account) { create(:account, customer_id: 'cus_123') }

        it { expect { job }.to change(enqueued_jobs, :size).by(1) }
        it { expect { job }.to_not change { account.reload.customer_id } }
        it { expect { job }.to_not change(account, :subscription_id) }
      end
    end
  end
end
