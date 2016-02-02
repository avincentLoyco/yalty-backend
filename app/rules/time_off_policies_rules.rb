module TimeOffPoliciesRules
  include BaseRules

  def post_rules
    Gate.rules do
      optional :end_day, :Integer, allow_nil: true
      optional :end_month, :Integer, allow_nil: true
      required :start_day, :Integer
      required :start_month, :Integer
      optional :amount, :Integer
      required :years_to_effect, :Integer
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
      required :id, :String
      optional :end_day, :Integer, allow_nil: true
      optional :end_month, :Integer, allow_nil: true
      required :start_day, :Integer
      required :start_month, :Integer
      optional :amount, :Integer
      required :years_to_effect, :Integer
      required :policy_type, :String
      optional :employees, :Array, allow_nil: true
      optional :working_places, :Array, allow_nil: true
    end
  end
end
