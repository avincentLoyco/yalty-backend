module Payments
  class CreateOrUpdateCustomerWithSubscription < ActiveJob::Base
    queue_as :billing

    class JobWrapper < CustomJobAdapter::JobWrapper
      sidekiq_options retry: 6
      sidekiq_retry_in { 10 }
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
        customer.description = account.stripe_description
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
          plan: "free-plan",
          quantity: account.employees.chargeable_at_date(Time.zone.tomorrow).count,
          tax_percent: Invoice::TAX_PERCENT
        )
        account.update!(subscription_id: subscription.id)
      else
        subscription = Stripe::Subscription.retrieve(account.subscription_id)
        subscription.tax_percent = Invoice::TAX_PERCENT
        subscription.save
      end
    end
  end
end
