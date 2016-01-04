module TimeOffsRules
  include BaseRules

  def post_rules
    Gate.rules do
      required :end_time
      required :start_time
      required :time_off_category, :Hash do
        required :id
      end
      required :employee, :Hash do
        required :id
      end
    end
  end

  def put_rules
    Gate.rules do
      required :start_time
      required :end_time
    end
  end
end
