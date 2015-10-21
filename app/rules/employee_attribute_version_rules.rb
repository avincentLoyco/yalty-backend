module EmployeeAttributeVersionRules
  include AttributeRules

  def patch_rules
    Gate.rules do
      optional :value, allow_nil: true 
      required :id
    end
  end

  def post_rules
    Gate.rules do
      optional :id
      required :attribute_name
      required :value, allow_nil: true 
    end
  end

  def put_rules
    Gate.rules do
      required :id
      required :value, allow_nil: true
    end
  end

end
