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
    customer = Stripe::Customer.create(
      description: account.stripe_description,
      metadata: { account_id: account.id }
    )
    Stripe::Subscription.create(customer: customer.id)
    account.update(customer_id: customer.id)
  end
end
