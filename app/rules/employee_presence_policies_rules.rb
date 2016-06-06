module EmployeePresencePoliciesRules
  include BaseRules

  def post_rules
    Gate.rules do
      required :presence_policy_id
      required :id
      required :effective_at
      required :order_of_start_day
    end
  end
end
