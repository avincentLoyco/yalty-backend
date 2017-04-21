require 'rails_helper'
require 'fakeredis/rspec'
require 'sidekiq/testing'

RSpec.describe Payments::CreateOrUpdateCustomerWithSubscription, type: :job do
  include ActiveJob::TestHelper

  let!(:account) { create(:account) }

  subject(:job) { described_class.perform_now(account) }

  before { allow_any_instance_of(Account).to receive(:stripe_enabled?).and_return(true) }

  context 'in case of success' do
    before do
      allow(Stripe::Customer).to receive(:create).and_return(customer)
      allow(Stripe::Customer).to receive(:retrieve).and_return(customer)
      allow(customer).to receive(:save)
      allow(Stripe::Subscription).to receive(:create).and_return(subscription)
      allow(Stripe::Subscription).to receive(:retrieve).and_return(subscription)
      allow(subscription).to receive(:save)
    end

    let(:customer) { StripeCustomer.new('cus_123') }
    let(:subscription) { StripeSubscription.new('sub_123') }

    context 'when customer does not exist' do
      it { expect { job }.to change(account, :customer_id).from(nil).to('cus_123') }
      it 'should create stripe cusomer' do
        job
        expect(Stripe::Customer).to have_received(:create)
      end
    end

    context 'when subscription does not exist' do
      it { expect { job }.to change(account, :subscription_id).from(nil).to('sub_123') }
      it 'should create stripe cusomer' do
        job
        expect(Stripe::Subscription).to have_received(:create)
      end
    end

    context 'when customer exists' do
      let!(:account) { create(:account, customer_id: 'cus_456') }

      it { expect { job }.to_not change(account, :customer_id) }
      it 'should update stripe cusomer' do
        job
        expect(customer).to have_received(:save)
      end
    end

    context 'when subscription exists' do
      let!(:account) { create(:account, customer_id: 'cus_456', subscription_id: 'sub_123') }

      it { expect { job }.to_not change(account, :subscription_id) }
      it 'should update stripe cusomer' do
        job
        expect(subscription).to have_received(:save)
      end
    end
  end
end
