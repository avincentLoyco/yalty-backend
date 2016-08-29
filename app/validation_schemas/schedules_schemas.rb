module SchedulesSchemas
  include BaseSchemas

  def get_schema
    Dry::Validation.Form do
      required(:to).filled(:str?)
      required(:from).filled(:str?)
    end
  end
end
