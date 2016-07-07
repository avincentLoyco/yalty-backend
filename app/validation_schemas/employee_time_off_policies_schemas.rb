module EmployeeTimeOffPoliciesSchemas
  include BaseSchemas

  def post_schema
    Dry::Validation.Form do
      required(:time_off_policy_id).filled(:str?)
      required(:id).filled(:str?)
      required(:effective_at).filled
    end
  end
end
