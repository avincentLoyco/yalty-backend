module PresenceDayRules
  include BaseRules

  def post_rules
    Gate.rules do
      required :order, :Integer
      optional :hours, :Decimal
      required :presence_policy, :Hash do
        required :id
      end
    end
  end

  def put_rules
    Gate.rules do
      required :id, :String
      required :order, :Integer
      optional :hours, :Decimal
    end
  end
end
