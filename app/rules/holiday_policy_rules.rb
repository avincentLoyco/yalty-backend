module HolidayPolicyRules
  include BaseRules

  def patch_rules
    Gate.rules do
      required :id, :String
      optional :name, :String
      optional :region, :String
      optional :country, :String
      optional :employees, :Array, allow_nil: true
      optional :working_places, :Array, allow_nil: true
    end
  end

  def post_rules
    Gate.rules do
      required :name, :String
      optional :region, :String
      optional :country, :String
      optional :employees, :Array, allow_nil: true
      optional :working_places, :Array, allow_nil: true
    end
  end

  def put_rules
    Gate.rules do
      required :id, :String
      required :name, :String
      optional :region, :String
      optional :country, :String
      optional :employees, :Array, allow_nil: true
      optional :working_places, :Array, allow_nil: true
    end
  end
end
