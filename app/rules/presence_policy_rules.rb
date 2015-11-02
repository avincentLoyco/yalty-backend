module PresencePolicyRules
  include BaseRules

  def post_rules
    Gate.rules do
      required :name, :String
      optional :employees, :Array
      optional :working_places, :Array
    end
  end

  def put_rules
    Gate.rules do
      required :id, :String
      required :name, :String
      optional :employees, :Array
      optional :working_places, :Array
    end
  end
end
