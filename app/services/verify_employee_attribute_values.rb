class VerifyEmployeeAttributeValues
  include ValuesRules
  attr_reader :value, :errors, :type, :ruby_type

  def initialize(employee_attribute)
    @value = employee_attribute[:value]
    @type = attribute_type(employee_attribute[:attribute_name])
    @ruby_type = attribute_ruby_type if type
    @errors = {}
  end

  def valid?
    return true unless ruby_type

    verify_value_type
    verify_nested_params

    errors.blank?
  end

  private

  def verify_value_type
    return if value_allowed?
    errors.merge!(value: 'Invalid type')
  end

  def verify_nested_params
    return unless value.is_a?(Hash) && ruby_type == 'Hash'
    result = gate_rules(type).verify(value)
    errors.merge!(result.errors) unless result.valid?
  end

  def value_allowed?
    [class_type?, nil?, date?, boolean?, decimal?].any?
  end

  def attribute_type(name)
    Account.current.employee_attribute_definitions.where(name: name).first.try(:attribute_type)
  end

  def attribute_ruby_type
    "Attribute::#{type}".classify.safe_constantize.ruby_type
  end

  def boolean?
    %w(true false).include?(value) && ruby_type == 'Boolean'
  end

  def decimal?
    value_is_number? && ruby_type == 'BigDecimal'
  end

  def date?
    value_is_date? && ruby_type == 'Date'
  end

  def class_type?
    value.is_a?(ruby_type.safe_constantize) unless ruby_type == 'Boolean'
  end

  def nil?
    value.is_a?(NilClass)
  end

  def value_is_number?
    true if Float(value) rescue false
  end

  def value_is_date?
    true if value.to_date rescue false
  end
end
