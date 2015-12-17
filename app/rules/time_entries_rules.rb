module TimeEntriesRules
  include BaseRules

  def post_rules
    Gate.rules do
      required :start_time
      required :end_time
      required :presence_day do
        required :id
      end
    end
  end

  def put_rules
    Gate.rules do
      required :start_time
      required :end_time
      required :id
    end
  end
end
