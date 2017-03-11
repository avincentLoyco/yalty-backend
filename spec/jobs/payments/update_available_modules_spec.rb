require 'rails_helper'
require 'fakeredis/rspec'
require 'sidekiq/testing'

RSpec.describe Payments::UpdateAvailableModules, type: :job do
  include ActiveJob::TestHelper

  let!(:account) { create(:account) }
  let(:plan_ids) { ['master-plan', 'super-plan', 'ultra-plan'] }
  let(:plans) do
    (plan_ids + ['free-plan']).map do |plan_id|
      StripePlan.new(plan_id, 500, 'chf', 'month', plan_id.titleize)
    end
  end
  let!(:subscription_items) do
    [
      StripeSubscriptionItem.new(SecureRandom.hex, plans.first),
      StripeSubscriptionItem.new(SecureRandom.hex, plans.second),
      StripeSubscriptionItem.new(SecureRandom.hex, plans.third)
    ]
  end

  subject(:job) { described_class.perform_now(account) }

  before do
    allow(Stripe::Subscription)
      .to receive_message_chain(:retrieve, :items)
      .and_return(subscription_items)
  end

  context 'success' do
    it { expect { job }.to change { account.available_modules }.from([]).to(plan_ids) }
  end

  context 'error' do
    before { allow(Stripe::Subscription).to receive(:retrieve).and_raise(Stripe::APIError) }

    it { expect { job }.to change(enqueued_jobs, :size).by(1) }
  end
end
