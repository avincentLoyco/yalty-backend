module EmployeeRules
  include BaseRules

  def put_rules
    Gate.rules do
      required :id
      optional :holiday_policy, allow_nil: true do
        required :id
      end
      optional :presence_policy, allow_nil: true do
        required :id
      end
      optional :time_off_policies, :Array, allow_nil: true
    end
  end
end
