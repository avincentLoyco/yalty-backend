module HolidayRules
  include BaseRules

  def patch_rules
    Gate.rules do
      required :id, :String
      optional :name, :String
      optional :date, :Date
      required :holiday_policy do
        required :id, :String
      end
    end
  end

  def post_rules
    Gate.rules do
      required :name, :String
      required :date, :Date
      required :holiday_policy do
        required :id, :String
      end
    end
  end

  def put_rules
    Gate.rules do
      required :id, :String
      required :name, :String
      required :date, :Date
      required :holiday_policy do
        required :id, :String
      end
    end
  end
end
