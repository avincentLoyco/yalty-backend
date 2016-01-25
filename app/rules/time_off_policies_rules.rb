module TimeOffPoliciesRules
  include BaseRules

  def post_rules
    Gate.rules do
      required :end_day
      required :end_month
      required :start_day
      required :start_month
      optional :amount
      required :years_passed
      required :years_to_effect
      required :policy_type
      required :time_off_category, :Hash do
        required :id
      end
      optional :employees, :Array
      optional :working_places, :Array
    end
  end

  def put_rules
    Gate.rules do
      required :id
      required :end_day
      required :end_month
      required :start_day
      required :start_month
      optional :amount
      required :years_passed
      required :years_to_effect
      required :policy_type
      required :time_off_category, :Hash do
        required :id
      end
      optional :employees, :Array
      optional :working_places, :Array
    end
  end
end
