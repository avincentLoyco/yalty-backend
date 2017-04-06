namespace :payments do
  desc 'Create Stripe customer and subscription for accounts'
  task create_customers: [:environment] do
    Account.where('customer_id IS NULL OR subscription_id IS NULL').find_each do |account|
      ::Payments::CreateOrUpdateCustomerWithSubscription.perform_now(account)
    end
  end

  desc 'Update Stripe customer and subscription for accounts'
  task update_customers: [:environment] do
    Account.find_each do |account|
      ::Payments::CreateOrUpdateCustomerWithSubscription.perform_later(account)
    end
  end
end
