module PresencePolicyRules
  include BaseRules

  def post_rules
    Gate.rules do
      required :name, :String
      optional :presence_days, :Array, allow_nil: true
    end
  end

  def put_rules
    Gate.rules do
      required :id, :String
      required :name, :String
    end
  end
end
