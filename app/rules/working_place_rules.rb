module WorkingPlaceRules
  include BaseRules

  def patch_rules
    Gate.rules do
      required :id, :String
      optional :name, :String
      optional :employees, :Array
      optional :holiday_policy, allow_nil: true do
        required :id
      end
    end
  end

  def post_rules
    Gate.rules do
      required :name, :String
      optional :employees, :Array
      optional :holiday_policy, allow_nil: true do
        required :id
      end
    end
  end

  def put_rules
    Gate.rules do
      required :id, :String
      required :name, :String
      optional :employees, :Array
      optional :holiday_policy, allow_nil: true do
        required :id
      end
    end
  end
end
