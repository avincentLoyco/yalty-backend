require 'rails_helper'
require 'fakeredis/rspec'
require 'sidekiq/testing'

RSpec.describe Payments::UpdateStripeCustomerDescription, type: :job do
  include ActiveJob::TestHelper

  let!(:account) { create(:account) }

  subject(:job) { described_class.perform_now(account) }

  context 'in case of success' do
    let(:customer) { StripeCustomer.new('cus_123', 'Some desc', 'test@emai.com') }

    before { allow(Stripe::Customer).to receive(:retrieve).and_return(customer) }

    it { expect { subject }.to change(customer, :description) }

    it { expect { subject }.to change(customer, :email) }

    it 'methods are invoked' do
      expect(customer).to receive(:save)
      subject
    end
  end
end
