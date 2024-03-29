module EmployeePresencePoliciesSchemas
  include BaseSchemas

  def post_schema
    Dry::Validation.Form do
      required(:presence_policy_id).filled(:str?)
      required(:employee_id).filled(:str?)
      required(:effective_at).filled(:date?)
      required(:order_of_start_day).filled
    end
  end

  def put_schema
    Dry::Validation.Form do
      required(:id).filled(:str?)
      required(:effective_at).filled(:date?)
      required(:order_of_start_day).filled(:int?)
    end
  end
end
