module TimeOffCategoriesSchemas
  include BaseSchemas

  def post_schema
    Dry::Validation.Form do
      required(:name).filled(:str?)
    end
  end

  def put_schema
    Dry::Validation.Form do
      required(:name).filled(:str?)
    end
  end
end
