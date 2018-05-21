namespace :staging do
  task check: :environment do
    raise "Do not run this task outside of staging environment" unless Rails.env.staging?
  end

  namespace :reset do
    task stripe: :'staging:check' do
      Invoice.delete_all

      Account.update_all(customer_id: nil, subscription_id: nil)
      Account.where(subdomain: ENV["TEST_ACCOUNTS"].split(" ")).find_each do |account|
        ::Payments::CreateOrUpdateCustomerWithSubscription.perform_now(account)

        subscription = Stripe::Subscription.retrieve(account.subscription_id)
        subscription.trial_end = 10.days.from_now.to_i
        subscription.save

        customer = Stripe::Customer.retrieve(account.customer_id)
        customer.sources.create(
          source: {
            object: "card",
            number: "4242424242424242",
            exp_month: "12",
            exp_year: Time.zone.today.year.to_s,
            cvc: "204",
          }
        )

        ::Payments::UpdateAvailableModules.perform_now(account)

        subscription = Stripe::Subscription.retrieve(account.subscription_id)
        subscription.trial_end = "now"
        subscription.save
      end
    end
  end
end
