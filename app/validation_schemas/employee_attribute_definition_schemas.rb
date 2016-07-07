module EmployeeAttributeDefinitionSchemas
  include BaseSchemas

  def post_schema
    Dry::Validation.Form do
      required(:name).filled
      optional(:label).filled
      required(:attribute_type).filled
      required(:system).filled
      optional(:multiple).filled
    end
  end

  def put_schema
    Dry::Validation.Form do
      required(:id).filled
      required(:name).filled
      optional(:label).filled
      required(:attribute_type).filled
      required(:system).filled
    end
  end
end
