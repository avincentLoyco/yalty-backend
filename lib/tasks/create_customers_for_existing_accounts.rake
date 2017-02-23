task create_customers_for_existing_accounts: [:environment] do
  Account.all.each do |account|
    next if account.customer_id.present? && account.subscription_id.present?
    Payments::CreateCustomerWithSubscription.perform_now(account)
  end
end
