require 'rails_helper'
require 'fakeredis/rspec'
require 'sidekiq/testing'

RSpec.describe CreateCustomerWithSubscription, type: :job do
  include ActiveJob::TestHelper

  let!(:account) { create(:account) }

  subject(:job) { described_class.perform_now(account) }

  context 'in case of success' do
    StripeCustomer = Struct.new(:id)
    let(:customer) { StripeCustomer.new('cus_123') }

    before do
      allow_any_instance_of(Account).to receive(:stripe_enabled?).and_return(true)
      allow(Stripe::Customer).to receive(:create).and_return(customer)
      allow(Stripe::Subscription).to receive(:create)
    end

    it { expect { job }.to change(account, :customer_id).from(nil).to('cus_123') }
  end

  context 'in case of error' do
    before do
      allow_any_instance_of(Account).to receive(:stripe_enabled?).and_return(true)
      allow(Stripe::Customer).to receive(:create).and_raise(Stripe::APIError)
    end

    it { expect { job }.to change(enqueued_jobs, :size).by(1) }
  end
end
