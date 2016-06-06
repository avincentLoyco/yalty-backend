module EmployeeWorkingPlacesRules
  include BaseRules

  def post_rules
    Gate.rules do
      required :working_place_id
      required :id
      required :effective_at
    end
  end
end
