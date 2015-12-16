class EmployeeAttributeVersionRules
  def gate_rules(request)
    return put_rules     if request.put?
    return post_rules    if request.post?
  end

  def post_rules
    Gate.rules do
      required :attribute_name
      required :value, :Any, allow_nil: true #do
      optional :order
    end
  end

  def put_rules
    Gate.rules do
      optional :id
      required :value, :Any, allow_nil: true
      required :attribute_name
      optional :order
    end
  end
end
