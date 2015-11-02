module HolidayRules
  include BaseRules

  def patch_rules
    Gate.rules do
      required :id, :String
      required :holiday_policy_id, :String
      optional :name, :String
      optional :date, :Date
    end
  end

  def post_rules
    Gate.rules do
      required :holiday_policy_id, :String
      required :name, :String
      required :date, :Date
    end
  end

  def put_rules
    Gate.rules do
      required :id, :String
      required :holiday_policy_id, :String
      required :name, :String
      required :date, :Date
    end
  end
end
