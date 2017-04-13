module Payments
  class Plan < ::BasicAttribute
    attribute :id, String
    attribute :name, String
    attribute :amount, Integer
    attribute :currency, String
    attribute :interval, String
    attribute :interval_count, Integer
    attribute :active, Boolean, default: true
  end
end
