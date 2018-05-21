require "rails_helper"

RSpec.describe Payments::UpdateAvailableModules, type: :job do
  let!(:account) { create(:account, :with_stripe_fields, available_modules: available_modules) }
  let(:available_modules) do
    available_modules = Payments::AvailableModules.new
    plan_ids.each do |plan_id|
      available_modules.add(id: plan_id)
    end
    available_modules
  end
  let(:plan_ids) { ["master-plan", "super-plan", "ultra-plan"] }
  let(:subscription) do
    subscription = StripeSubscription.new(account.subscription_id || SecureRandom.hex)
    subscription.items = subscription_items
    subscription.current_period_end = 1.day.from_now
    subscription
  end
  let(:subscription_items) { [] }

  subject(:job) { described_class.perform_now(account) }

  before do
    allow(Stripe::Subscription).to receive(:retrieve).and_return(subscription)
    allow(Stripe::SubscriptionItem).to receive(:create)
  end

  context "when subscription item missing" do
    before { job }

    it "create missing subscription items" do
      expect(Stripe::SubscriptionItem).to have_received(:create).exactly(3)
    end
  end

  context "when subscription exist" do
    let(:subscription_items) do
      [
        StripeSubscriptionItem.new(SecureRandom.hex, StripePlan.new(plan_ids.first)),
      ]
    end

    before { job }

    it "create missing subscription items" do
      expect(Stripe::SubscriptionItem).to have_received(:create).exactly(2)
    end
  end
end
