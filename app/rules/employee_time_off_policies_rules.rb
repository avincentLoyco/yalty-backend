module EmployeeTimeOffPoliciesRules
  include BaseRules

  def post_rules
    Gate.rules do
      required :time_off_policy_id
      required :id
      required :effective_at
    end
  end
end
