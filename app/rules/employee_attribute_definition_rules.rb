module EmployeeAttributeDefinitionRules
  include BaseRules

  def patch_rules
    Gate.rules do
      required :id
      optional :name
      optional :label
      optional :attribute_type
      optional :system
    end
  end

  def post_rules
    Gate.rules do
      required :name
      optional :label
      required :attribute_type
      required :system
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
