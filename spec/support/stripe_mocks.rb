StripeSubscription = Struct.new(:id)
StripeCustomer = Struct.new(:id, :description) do
  def save
    'I wish I was a real method'
  end
end
