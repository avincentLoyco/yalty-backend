class EmployeeAttributeVersionRules

  def gate_rules(request)
    return put_rules     if request.put?
    return patch_rules   if request.patch?
    return post_rules    if request.post?
  end

  def patch_rules
    Gate.rules do
      optional :value, allow_nil: true
      required :id
    end
  end

  def post_rules
    Gate.rules do
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
