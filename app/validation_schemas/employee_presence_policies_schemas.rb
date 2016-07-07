module EmployeePresencePoliciesSchemas
  include BaseSchemas

  def post_schema
    Dry::Validation.Form do
      required(:presence_policy_id).filled(:str?)
      required(:id).filled(:str?)
      required(:effective_at).filled
      required(:order_of_start_day).filled
    end
  end
end
