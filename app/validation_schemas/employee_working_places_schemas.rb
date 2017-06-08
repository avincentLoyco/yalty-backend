module EmployeeWorkingPlacesSchemas
  include BaseSchemas

  def post_schema
    Dry::Validation.Form do
      required(:working_place_id).filled(:str?)
      required(:employee_id).filled(:str?)
      required(:effective_at).filled(:date?)
    end
  end

  def put_schema
    Dry::Validation.Form do
      required(:id).filled(:str?)
      required(:effective_at).filled(:date?)
    end
  end
end
