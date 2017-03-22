module EmployeeAttributesSchemas
  include BaseSchemas

  def get_schema
    Dry::Validation.Form do
      required(:employee_id).filled(:str?)
      required(:date).filled(:date?)
    end
  end
end
