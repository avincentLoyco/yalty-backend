module TimeOffsSchemas
  include BaseSchemas

  def post_schema
    Dry::Validation.Form do
      required(:start_time).filled
      required(:end_time).filled
      required(:time_off_category).schema do
        required(:id).filled(:str?)
      end
      required(:employee).schema do
        required(:id).filled(:str?)
      end
    end
  end

  def put_schema
    Dry::Validation.Form do
      required(:start_time).filled
      required(:end_time).filled
    end
  end
end
