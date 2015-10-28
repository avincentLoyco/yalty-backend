module WorkingPlaceRules
  include BaseRules

  def post_rules
    Gate.rules do
      required :name, :String
      optional :employees, :Array, allow_nil: true
      optional :holiday_policy, allow_nil: true do
        required :id
      end
      optional :presence_policy, allow_nil: true do
        required :id
      end
    end
  end

  def put_rules
    Gate.rules do
      required :id, :String
      required :name, :String
      optional :employees, :Array, allow_nil: true
      optional :holiday_policy, allow_nil: true do
        required :id
      end
      optional :presence_policy, allow_nil: true do
        required :id
      end
    end
  end
end
