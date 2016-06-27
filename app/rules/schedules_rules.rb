module SchedulesRules
  include BaseRules

  def get_rules
    Gate.rules do
      required :to, :String
      required :from, :String
    end
  end
end
