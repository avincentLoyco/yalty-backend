class EmployeeAttributeVersionSchemas
  def dry_validation_schema(request)
    return put_schema     if request.put?
    return post_schema    if request.post?
  end

  def post_schema
    Dry::Validation.Form do
      required(:attribute_name).filled
      required(:value).maybe
      optional(:order).filled
    end
  end

  def put_schema
    Dry::Validation.Form do
      optional(:id).filled(:str?)
      required(:value).maybe
      required(:attribute_name).filled
      optional(:order).filled
    end
  end
end
