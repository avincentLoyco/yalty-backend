StripeSubscription = Struct.new(:id, :current_period_end, :items, :status, :customer, :object,
  :trial_end, :tax_percent, :save)
StripeCustomer = Struct.new(:id, :description, :email, :default_source, :sources, :metadata, :save, :delete)
StripeInvoice = Struct.new(:id, :amount_due, :date, :lines, :upcoming, :data, :receipt_number, :tax,
  :tax_percent, :starting_balance, :subtotal, :total)
StripePlan = Struct.new(:id, :amount, :currency, :interval, :name, :active, :trial_period_days, :free, :enabled)
StripeCard = Struct.new(:id, :last4, :brand, :exp_month, :exp_year, :default, :name)
StripeEvent = Struct.new(:id, :type)
StripeSubscriptionItem =
  Struct.new(:id, :plan, :quantity, :delete, :save, :prorate, :proration_date, :status)
