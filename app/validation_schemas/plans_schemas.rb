module PlansSchemas
  include BaseSchemas

  def post_schema
    Dry::Validation.Form do
      required(:id).filled(:str?)
    end
  end

  def delete_schema
    Dry::Validation.Form do
      required(:id).filled(:str?)
    end
  end
end
