module EmployeeTimeOffPoliciesSchemas
  include BaseSchemas

  def post_schema
    Dry::Validation.Form do
      required(:time_off_policy_id).filled(:str?)
      required(:id).filled(:str?)
      required(:effective_at).filled
      optional(:employee_balance_amount).maybe(:str?)
    end
  end

  def put_schema
    Dry::Validation.Form do
      required :id
      required :effective_at
    end
  end
end
