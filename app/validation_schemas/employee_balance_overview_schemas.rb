module EmployeeBalanceOverviewSchemas
  include BaseSchemas

  def read_schema
    Dry::Validation.Form do
      optional(:category).filled(:str?)
      optional(:date).filled(:date?)
    end
  end
end
