module EmployeeAttributeDefinitionRules
  include BaseRules

  def post_rules
    Gate.rules do
      required :name
      optional :label
      required :attribute_type
      required :system
      optional :multiple
    end
  end

  def put_rules
    Gate.rules do
      required :id
      required :name
      optional :label
      required :attribute_type
      required :system
    end
  end
end
