namespace :payments do
  desc 'Create Stripe customer and subscription for accounts'
  task create_customers_for_existing_accounts: [:environment] do
    Account.where('customer_id IS NULL OR subscription_id IS NULL').each do |account|
      ::Payments::CreateCustomerWithSubscription.perform_now(account)
    end
  end
end
