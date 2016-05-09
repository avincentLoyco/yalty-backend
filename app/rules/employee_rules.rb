module EmployeeRules
  include BaseRules

  def put_rules
    Gate.rules do
      required :id
      optional :holiday_policy, allow_nil: true do
        required :id
      end
    end
  end
end
