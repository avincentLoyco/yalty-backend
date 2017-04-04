StripeSubscription = Struct.new(:id, :current_period_end, :items, :status, :customer, :object)
StripeCustomer = Struct.new(:id, :description, :email, :default_source, :sources, :save)
StripeInvoice = Struct.new(:id, :amount_due, :date, :lines, :upcoming, :data, :receipt_number, :tax,
  :tax_percent, :starting_balance, :subtotal, :total)
StripePlan = Struct.new(:id, :amount, :currency, :interval, :name, :active)
StripeCard = Struct.new(:id, :last4, :brand, :exp_month, :exp_year, :default, :name)
StripeEvent = Struct.new(:id, :type)
StripeSubscriptionItem =
  Struct.new(:id, :plan, :quantity, :delete, :save, :prorate, :proration_date)
