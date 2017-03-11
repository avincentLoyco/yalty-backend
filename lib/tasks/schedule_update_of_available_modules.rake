namespace :payments do
  desc 'Updates available_modules for each account'
  task schedule_update_of_available_modules: [:environment] do
    Account.where.not(customer_id: nil, subscription_id: nil).each do |account|
      ::Payments::UpdateAvailableModules.perform_now(account)
    end
    Rake::Task['payments:create_customers_for_existing_accounts'].invoke
  end
end
