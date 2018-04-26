module SchedulesSchemas
  include BaseSchemas

  def read_schema
    Dry::Validation.Form do
      required(:to).filled(:str?)
      required(:from).filled(:str?)
    end
  end
end
