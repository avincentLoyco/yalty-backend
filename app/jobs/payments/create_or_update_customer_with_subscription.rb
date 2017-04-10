module Payments
  class CreateOrUpdateCustomerWithSubscription < ActiveJob::Base
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
      create_or_update_customer(account)
      create_or_update_subscription(account)
    end

    private

    def create_or_update_customer(account)
      if account.customer_id.nil?
        customer = Stripe::Customer.create(
          description: account.stripe_description,
          email: account.stripe_email,
          metadata: customer_metadata(account)
        )
        account.update!(customer_id: customer.id)
      else
        customer = Stripe::Customer.retrieve(account.customer_id)
        customer.email = account.stripe_email
        customer.description = account.stripe_email
        customer.metadata = customer_metadata(account)
        customer.save
      end
    end

    def customer_metadata(account)
      {
        account_id: account.id
      }
    end

    def create_or_update_subscription(account)
      return unless account.customer_id?

      if account.subscription_id.nil?
        subscription = Stripe::Subscription.create(
          customer: account.customer_id,
          plan: 'free-plan',
          quantity: account.employees.active_at_date(Time.zone.tomorrow).count,
          tax_percent: 8.0
        )
        account.update!(subscription_id: subscription.id)
      else
        subscription = Stripe::Subscription.retrieve(account.subscription_id)
        subscription.tax_percent = 8.0
        subscription.save
      end
    end
  end
end
