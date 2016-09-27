module EmployeeEventSchemas
  include BaseSchemas

  def post_schema
    Dry::Validation.Form do
      required(:effective_at).filled
      required(:event_type).filled(:str?)
      optional(:comment).filled(:str?)
      required(:employee).schema do
        optional(:id).filled(:str?)
        optional(:working_place_id).filled(:str?)
      end
      optional(:employee_attributes).maybe(:array?)
    end
  end

  def put_schema
    Dry::Validation.Form do
      required(:id).filled(:str?)
      required(:effective_at).filled
      required(:event_type).filled(:str?)
      optional(:comment).filled(:str?)
      required(:employee).schema do
        required(:id).filled(:str?)
      end
      optional(:employee_attributes).maybe(:array?)
    end
  end
end
