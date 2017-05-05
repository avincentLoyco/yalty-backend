module Payments
  class UpdateStripeCustomerDescription < ActiveJob::Base
    queue_as :billing

    class JobWrapper < CustomJobAdapter::JobWrapper
      sidekiq_options retry: 6
      sidekiq_retry_in { 10 }
    end

    def perform(account)
      customer = Stripe::Customer.retrieve(account.customer_id)
      customer.description = account.stripe_description
      customer.email = account.stripe_email
      customer.save
    end
  end
end
