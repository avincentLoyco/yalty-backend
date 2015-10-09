module HolidayPolicyRules
  include BaseRules

  def patch_rules
    Gate.rules do
      required :id, :String
      required :name, :String
      optional :region, :String
      optional :country, :String
      optional :employees, :Array
      optional :working_places, :Array
      optional :holidays, :Array
    end
  end

  def post_rules
    Gate.rules do
      required :name, :String
      optional :region, :String
      optional :country, :String
      optional :employees, :Array
      optional :working_places, :Array
      optional :holidays, :Array
    end
  end

  def put_rules
    Gate.rules do
      required :id, :String
      required :name, :String
      optional :region, :String
      optional :country, :String
      optional :employees, :Array
      optional :working_places, :Array
      optional :holidays, :Array
    end
  end
end
