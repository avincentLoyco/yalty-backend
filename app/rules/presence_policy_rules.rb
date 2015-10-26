module PresencePolicyRules
  include BaseRules

  def patch_rules
    Gate.rules do
      required :id, :String
      optional :name, :String
      optional :employees, :Array
      optional :working_places, :Array
      optional :presence_days, :Array
    end
  end

  def post_rules
    Gate.rules do
      required :name, :String
      optional :employees, :Array
      optional :working_places, :Array
      optional :presence_days, :Array
    end
  end

  def put_rules
    Gate.rules do
      required :id, :String
      required :name, :String
      optional :employees, :Array
      optional :working_places, :Array
      optional :presence_days, :Array
    end
  end
end
