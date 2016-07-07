module TimeEntriesSchemas
  include BaseSchemas

  def post_schema
    Dry::Validation.Form do
      required(:start_time).filled
      required(:end_time).filled
      required(:presence_day).schema do
        required(:id).filled(:str?)
      end
    end
  end

  def put_schema
    Dry::Validation.Form do
      required(:start_time).filled
      required(:end_time).filled
      required(:id).filled(:str?)
    end
  end
end
