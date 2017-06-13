module EmployeeEventSchemas
  include BaseSchemas

  def post_schema
    Dry::Validation.Form do
      required(:effective_at).filled(:date?)
      required(:event_type).filled(:str?)
      required(:employee).schema do
        optional(:id).filled(:str?)
      end
      optional(:employee_attributes).maybe do
        each do
          required(:attribute_name).filled
          required(:value).maybe
          optional(:order).filled
        end
      end
    end
  end

  def put_schema
    Dry::Validation.Form do
      required(:id).filled(:str?)
      required(:effective_at).filled(:date?)
      required(:event_type).filled(:str?)
      required(:employee).schema do
        required(:id).filled(:str?)
      end
      optional(:employee_attributes).maybe do
        each do
          optional(:id).filled(:str?)
          required(:value).maybe
          required(:attribute_name).filled
          optional(:order).filled
        end
      end
    end
  end
end
