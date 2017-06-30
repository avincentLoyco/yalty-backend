namespace :fix_employees_quantity do
  desc 'Fix quantity for accounts in stripe'
  task update_stripe: :environment do
    Account.where.not(subscription_id: nil).find_each do |account|
      employees_count = account.employees.chargeable_at_date(Time.zone.today).count
      Stripe::SubscriptionItem.list(subscription: account.subscription_id).each do |sub_item|
        next if sub_item.quantity.eql?(employees_count)
        sub_item.quantity = employees_count
        sub_item.proration_date = Time.zone.now.to_i
        sub_item.save
      end
    end
  end
end
