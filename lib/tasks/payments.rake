namespace :payments do
  desc 'Create Stripe customer and subscription for accounts'
  task create_customers_for_existing_accounts: [:environment] do
    Account.where('customer_id IS NULL OR subscription_id IS NULL').find_each do |account|
      ::Payments::CreateOrUpdateCustomerWithSubscription.perform_now(account)
    end
  end

  desc 'Update Stripe customer and subscription for accounts'
  task update_customers_for_existing_accounts: [:environment] do
    Account.find_each do |account|
      ::Payments::CreateOrUpdateCustomerWithSubscription.perform_later(account)
    end
  end

  desc 'Updates available_modules for each account'
  task schedule_update_of_available_modules: [:environment] do
    Account.where.not(customer_id: nil, subscription_id: nil).each do |account|
      ::Payments::UpdateAvailableModules.perform_now(account)
    end
    Rake::Task['payments:create_customers_for_existing_accounts'].invoke
  end

  desc 'Create missing receipt_numbers for paid invoices'
  task create_missing_receipt_numbers: :environment do
    ActiveRecord::Base.connection.execute(update_receipt_numbers)
  end

  def update_receipt_numbers
    "
      UPDATE invoices
      SET receipt_number = nextval('receipt_number_seq')
      WHERE
        invoices.status = 'success' AND
        invoices.receipt_number IS NULL
    "
  end
end
