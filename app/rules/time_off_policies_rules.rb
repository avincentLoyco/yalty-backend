module TimeOffPoliciesRules
  include BaseRules

  def post_rules
    Gate.rules do
      required :name, :String
      optional :end_day, :Integer, allow_nil: true
      optional :end_month, :Integer, allow_nil: true
      required :start_day, :Integer
      required :start_month, :Integer
      optional :amount, :Integer
      optional :years_to_effect, :Integer, allow_nil: true
      required :policy_type, :String
      required :time_off_category, :Hash do
        required :id, :String
      end
      optional :employees, :Array, allow_nil: true
      optional :working_places, :Array, allow_nil: true
    end
  end

  def put_rules
    Gate.rules do
      optional :name, :String
      required :id, :String
      optional :end_day, :Integer, allow_nil: true
      optional :end_month, :Integer, allow_nil: true
      required :start_day, :Integer
      required :start_month, :Integer
      optional :amount, :Integer
      optional :years_to_effect, :Integer, allow_nil: true
      required :policy_type, :String
      optional :employees, :Array, allow_nil: true
      optional :working_places, :Array, allow_nil: true
    end
  end
end
