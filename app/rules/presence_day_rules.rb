module PresenceDayRules
  include BaseRules

  def post_rules
    Gate.rules do
      required :presence_policy_id, :String
      required :order, :Integer
      optional :hours, :Decimal
    end
  end

  def put_rules
    Gate.rules do
      required :id, :String
      required :presence_policy_id, :String
      required :order, :Integer
      optional :hours, :Decimal
    end
  end
end
