StripeSubscription = Struct.new(:id, :current_period_end, :quantity)
StripeCustomer = Struct.new(:id, :description) do
  def save
    'I wish I was a real method'
  end
end
StripeInvoice = Struct.new(:id, :amount_due, :date, :lines)
StripePlan = Struct.new(:id, :amount, :currency, :interval, :name, :active)
StripeSubscriptionItem = Struct.new(:id, :plan)
