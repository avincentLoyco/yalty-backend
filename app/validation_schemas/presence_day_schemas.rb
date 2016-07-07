module PresenceDaySchemas
  include BaseSchemas

  def post_schema
    Dry::Validation.Form do
      required(:order).filled(:int?)
      required(:presence_policy).schema do
        required(:id).filled(:str?)
      end
    end
  end

  def put_schema
    Dry::Validation.Form do
      required(:id).filled(:str?)
      required(:order).filled(:int?)
    end
  end
end
