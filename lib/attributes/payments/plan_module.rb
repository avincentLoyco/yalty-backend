module Payments
  class PlanModule < ::SimpleAttribute
    attribute :id, String
    attribute :canceled, Boolean
  end
end
