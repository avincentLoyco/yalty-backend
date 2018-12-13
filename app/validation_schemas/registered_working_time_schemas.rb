module RegisteredWorkingTimeSchemas
  include BaseSchemas

  def post_schema
    Dry::Validation.Form do
      required(:date).filled(:date?)
      required(:employee_id).filled(:str?)
      required(:time_entries).each do
        schema do
          required(:start_time).filled(:str?)
          required(:end_time).filled(:str?)
        end
      end
      required(:comment).maybe(:str?)
    end
  end

  def registered_time_entries_schema
    Dry::Validation.Form do
      required(:start_time).filled
      required(:end_time).filled
    end
  end
end
