module TimeOffCategoriesSchemas
  include BaseSchemas

  def post_schema
    Dry::Validation.Form do
      required(:name).filled(:str?)
      required(:auto_approved).filled(:bool?)
    end
  end

  def put_schema
    Dry::Validation.Form do
      required(:name).filled(:str?)
      required(:auto_approved).filled(:bool?)
    end
  end
end
