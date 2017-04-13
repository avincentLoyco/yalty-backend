module Payments
  class PlanModule < ::BasicAttribute
    attribute :id, String
    attribute :canceled, Boolean
  end
end
