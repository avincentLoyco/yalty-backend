class VerifyEmployeeAttributeValues
  include Attributes::PersonRules
  attr_reader :value, :errors, :type, :ruby_type

  def initialize(employee_attribute)
    @value = employee_attribute.select { |k, v| k.to_s == "value" }
    @type = attribute_type(employee_attribute[:attribute_name])
    @errors = {}
  end

  def valid?
    return true unless type
    verify_value

    errors.blank?
  end

  private

  def verify_value
    result = type_rules.verify(value)
    return if result.valid?
    errors.merge!(result.errors)
  end

  def type_rules
    send("#{type.downcase}_rules")
  end

  def attribute_type(name)
    Account.current.employee_attribute_definitions.where(name: name).first.try(:attribute_type)
  end
end
