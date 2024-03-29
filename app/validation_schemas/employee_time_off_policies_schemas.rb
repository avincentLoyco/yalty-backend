module EmployeeTimeOffPoliciesSchemas
  include BaseSchemas

  def post_schema
    Dry::Validation.Form do
      required(:time_off_policy_id).filled(:str?)
      required(:employee_id).filled(:str?)
      required(:effective_at).filled(:date?)
      optional(:employee_balance_amount).maybe(:str?)
    end
  end

  def put_schema
    Dry::Validation.Form do
      required(:id).filled(:str?)
      required(:effective_at).filled(:date?)
    end
  end
end
