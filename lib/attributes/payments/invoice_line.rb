module Payments
  class InvoiceLine < ::SimpleAttribute
    attribute :id, String
    attribute :amount, Integer
    attribute :currency, String
    attribute :period_start, DateTime
    attribute :period_end, DateTime
    attribute :proration, Boolean
    attribute :quantity, Integer
    attribute :subscription, String
    attribute :subscription_item, String
    attribute :type, String
    attribute :plan, Plan
  end
end
