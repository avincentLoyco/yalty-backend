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
    return if included_in_allowed?
    errors.merge!({ value: 'Invalid type' })
  end

  def verify_nested_params
    return unless value.is_a?(Hash)
    result = gate_rules(type).verify(value)
    errors.merge!(result.errors) unless result.valid?
  end

  def included_in_allowed?
    allowed_value_types.map { |allowed| value.is_a?(allowed) }.any?
  end

  def allowed_value_types
    [Hash, String, NilClass]
  end
end
