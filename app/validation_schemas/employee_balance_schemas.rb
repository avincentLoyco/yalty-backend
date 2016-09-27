module EmployeeBalanceSchemas
  include BaseSchemas

  def put_schema
    Dry::Validation.Form do
      required(:id).filled(:str?)
      required(:manual_amount).filled(:int?)
    end
  end
end
