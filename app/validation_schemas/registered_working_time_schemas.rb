module RegisteredWorkingTimeSchemas
  include BaseSchemas

  def post_schema
    Dry::Validation.Form do
      required(:date).filled
      required(:employee_id).filled(:str?)
      required(:time_entries).maybe(:array?)
    end
  end

  def registered_time_entries_schema
    Dry::Validation.Form do
      required(:start_time).filled
      required(:end_time).filled
    end
  end
end
