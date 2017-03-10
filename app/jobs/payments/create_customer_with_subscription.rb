module Payments
  class CreateCustomerWithSubscription < ActiveJob::Base
    queue_as :billing

    rescue_from(
      Stripe::InvalidRequestError,
      Stripe::AuthenticationError,
      Stripe::PermissionError,
      Stripe::RateLimitError,
      Stripe::APIError
    ) do
      retry_job(wait: 10.seconds)
    end

    def perform(account)
      create_customer(account)
      create_subscription(account)
    end

    private

    def create_customer(account)
      return if account.customer_id.present?
      account.update!(customer_id:
        Stripe::Customer.create(
          description: account.stripe_description,
          metadata: { account_id: account.id }
        ).id
      )
    end

    def create_subscription(account)
      return if account.customer_id.nil? || account.subscription_id.present?
      subscription = Stripe::Subscription.create(customer: account.customer_id, plan: 'free-plan')
      account.update!(subscription_id: subscription.id)
    end
  end
end
