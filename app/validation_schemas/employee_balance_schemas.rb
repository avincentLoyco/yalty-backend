module EmployeeBalanceSchemas
  include BaseSchemas

  def post_schema
    Dry::Validation.Form do
      required(:manual_amount).filled(:int?)
      optional(:effective_at).filled
      required(:employee).schema do
        required(:id).filled(:str?)
      end
      required(:time_off_category).schema do
        required(:id).filled(:str?)
      end
    end
  end

  def put_schema
    Dry::Validation.Form do
      required(:id).filled(:str?)
      required(:manual_amount).filled(:int?)
    end
  end
end
