module Payments
  class UpdateStripeCustomerDescription < ActiveJob::Base
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
      customer = Stripe::Customer.retrieve(account.customer_id)
      customer.description = account.stripe_description
      customer.email = account.stripe_email
      customer.save
    end
  end
end
