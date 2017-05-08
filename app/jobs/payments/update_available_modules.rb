module Payments
  class UpdateAvailableModules < ActiveJob::Base
    queue_as :billing

    class JobWrapper < CustomJobAdapter::JobWrapper
      sidekiq_options retry: 6
      sidekiq_retry_in { 10 }
    end

    def perform(account)
      return unless account.subscription_id?

      @subscription = Stripe::Subscription.retrieve(account.subscription_id)
      subscribed_plans = @subscription.items.map { |i| i.plan.id }.reject { |p| p == 'free-plan' }

      (account.available_modules.all - subscribed_plans).each_with_index do |plan_id, index|
        @subscription = Stripe::Subscription.retrieve(account.subscription_id) if index == 1
        params = {
          subscription: account.subscription_id,
          plan: plan_id,
          quantity: account.employees.active_at_date.count,
          prorate: index.positive? || !subscribed_plans.empty?
        }
        params[:proration_date] = proration_date(Time.zone.today) if params[:prorate]
        Stripe::SubscriptionItem.create(params)
      end
    end

    private

    def proration_date(date)
      DateTime.new(date.year, date.month, date.day, current_period_end.hour,
        current_period_end.min, current_period_end.sec, current_period_end.zone).to_i
    end

    def current_period_end
      @current_period_end ||= Time.zone.at(@subscription.current_period_end)
    end
  end
end
