module EmployeeWorkingPlacesSchemas
  include BaseSchemas

  def post_schema
    Dry::Validation.Form do
      required(:working_place_id).filled(:str?)
      required(:id).filled(:str?)
      required(:effective_at).filled
    end
  end
end
