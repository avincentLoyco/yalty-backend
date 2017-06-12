module AvailableModulesSchemas
  include BaseSchemas

  def put_schema
    Dry::Validation.Form do
      required(:id).filled(:str?)
      required(:free).filled(:bool?)
    end
  end
end
