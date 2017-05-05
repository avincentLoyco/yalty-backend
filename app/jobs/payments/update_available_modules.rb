module Payments
  class UpdateAvailableModules < ActiveJob::Base
    queue_as :billing

    class JobWrapper < CustomJobAdapter::JobWrapper
      sidekiq_options retry: 6
      sidekiq_retry_in { 10 }
    end

    def perform(account)
      account.update!(
        available_modules: ::Payments::AvailableModules.new(data: available_modules(account))
      )
    end

    private

    def available_modules(account)
      Stripe::Subscription.retrieve(account.subscription_id)
                          .items.each_with_object([]) do |sub_item, modules|
        if sub_item.plan.present? && !sub_item.plan.id.eql?('free-plan')
          modules.push(::Payments::PlanModule.new(id: sub_item.plan.id, canceled: false))
        end
      end
    end
  end
end
