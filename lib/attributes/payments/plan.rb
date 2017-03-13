module Payments
  class Plan < Basic
    attribute :id, String
    attribute :name, String
    attribute :amount, Integer
    attribute :currency, String
    attribute :interval, String
    attribute :interval_count, Integer
  end
end
