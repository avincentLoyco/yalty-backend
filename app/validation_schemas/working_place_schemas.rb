module WorkingPlaceSchemas
  include BaseSchemas

  def post_schema
    Dry::Validation.Form do
      required(:name).filled(:str?)
      optional(:holiday_policy).maybe do
        schema do
          required(:id).filled(:str?)
        end
      end
    end
  end

  def put_schema
    Dry::Validation.Form do
      required(:id).filled(:str?)
      required(:name).filled(:str?)
      optional(:holiday_policy).maybe do
        schema do
          required(:id).filled(:str?)
        end
      end
    end
  end
end
