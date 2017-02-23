require 'rails_helper'
require 'fakeredis/rspec'
require 'sidekiq/testing'

RSpec.describe Payments::UpdateStripeCustomerDescription, type: :job do
  include ActiveJob::TestHelper

  let!(:account) { create(:account) }

  subject(:job) { described_class.perform_now(account) }

  context 'in case of success' do
    let(:customer) { StripeCustomer.new('cus_123', 'Some desc') }

    before { allow(Stripe::Customer).to receive(:retrieve).and_return(customer) }

    it { expect { subject }.to change(customer, :description) }

    it 'methods are invoked' do
      expect(customer).to receive(:save)
      subject
    end
  end

  context 'in case of error' do
    before { allow(Stripe::Customer).to receive(:retrieve).and_raise(Stripe::APIError) }

    it { expect { job }.to change(enqueued_jobs, :size).by(1) }
  end
end
