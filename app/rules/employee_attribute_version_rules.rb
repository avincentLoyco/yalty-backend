class EmployeeAttributeVersionRules
  def gate_rules(request)
    return put_rules     if request.put?
    return post_rules    if request.post?
  end

  def post_rules
    # values = nested_values
    Gate.rules do
      required :attribute_name
      required :value, :Any, allow_nil: true #do
      #   values.flatten.each do |value|
      #     optional value
      #   end
      # end
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

  # def nested_values
  #   %w(Address Child Person).map do |type|
  #     "Attribute::#{type}".constantize.new.attributes.tap do |attr|
  #       attr.delete(:attribute_type)
  #     end.keys
  #   end
  # end
end
