FactoryGirl.define do
  factory :invoice do
    account
    amount_due { Faker::Number.between(1000, 2000) }
    status { 'pending' }
    date { Faker::Date.backward(10) }
    lines {
      Payments::InvoiceLines.new(data: [Payments::InvoiceLine.new(
        id: Faker::Number.hexadecimal(6),
        amount: Faker::Number.between(-1000, 1000),
        currency: 'chf',
        period_start: Faker::Date.backward(14),
        period_end: Faker::Date.forward(14),
        proration: true,
        quantity: Faker::Number.between(1, 50),
        subscription: Faker::Number.hexadecimal(6),
        subscription_item: Faker::Number.hexadecimal(6),
        type: 'invoiceitem',
        plan: {
          id: Faker::Number.hexadecimal(6),
          name: Faker::Lorem.word,
          amount: Faker::Number.between(100, 1000),
          currency: 'chf',
          interval: 'month',
          interval_count: 1
        }
      )])
    }
  end
end
