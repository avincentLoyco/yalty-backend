class VerifyEmployeeAttributeValues
  include ValuesRules
  attr_reader :value, :errors, :type

  def initialize(employee_attribute)
    @value = employee_attribute[:value]
    @type = employee_attribute[:attribute_name]
    @errors = {}
  end

  def valid?
    verify_value_type
    verify_nested_params

    errors.blank?
  end

  def errors
    @errors
  end

  private

  def verify_value_type
    return if value_allowed?
    errors.merge!({ value: 'Invalid type' })
  end

  def verify_nested_params
    return unless value.is_a?(Hash) && attribute_class_defined?
    result = gate_rules(type).verify(value)
    errors.merge!(result.errors) unless result.valid?
  end

  def value_allowed?
    attribute_class_defined? && value.is_a?(Hash) || value.is_a?(NilClass) ||
      !attribute_class_defined? && value.is_a?(String)
  end

  def attribute_class_defined?
    Object.const_defined?("Attribute::#{type.gsub(/[^0-9A-Za-z]/, '').classify}")
  end
end
