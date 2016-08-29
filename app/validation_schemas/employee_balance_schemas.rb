module EmployeeBalanceSchemas
  include BaseSchemas

  def post_schema
    Dry::Validation.Form do
      required(:amount).filled(:int?)
      optional(:effective_at).filled
      optional(:validity_date).filled
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
      optional(:effective_at).filled
      optional(:validity_date).maybe
      required(:amount).filled(:int?)
    end
  end
end
