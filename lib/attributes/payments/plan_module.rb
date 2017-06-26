module Payments
  class PlanModule < ::SimpleAttribute
    attribute :id, String
    attribute :canceled, Boolean
    attribute :free, Boolean
  end
end
