module RegisteredWorkingTimeRules
  include BaseRules

  def post_rules
    Gate.rules do
      required :date
      required :employee_id
      required :time_entries, :Array , allow_nil: true
    end
  end

  def registered_time_entries_rules
    Gate.rules do
      required :start_time
      required :end_time
    end
  end
end
