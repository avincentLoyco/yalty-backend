module PresencePolicyRules
  include BaseRules

  def post_rules
    Gate.rules do
      required :name, :String
      optional :employees, :Array, allow_nil: true
      optional :working_places, :Array, allow_nil: true
      optional :presence_days, :Array, allow_nil: true
    end
  end

  def put_rules
    Gate.rules do
      required :id, :String
      required :name, :String
      optional :employees, :Array, allow_nil: true
      optional :working_places, :Array, allow_nil: true
    end
  end
end
