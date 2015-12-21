class VerifyEmployeeAttributeValues
  include Attributes::PersonRules, Attributes::StringRules, Attributes::NumberRules,
    Attributes::AddressRules, Attributes::BooleanRules, Attributes::ChildRules,
    Attributes::CurrencyRules, Attributes::DateRules, Attributes::LineRules

  attr_reader :value, :errors, :type

  def initialize(employee_attribute)
    @value = employee_attribute.select { |k, _v| k.to_s == 'value' }
    @type = attribute_type(employee_attribute[:attribute_name])
    @errors = {}
  end

  def valid?
    return true unless type && !value[:value].nil?
    verify_value

    errors.blank?
  end

  private

  def verify_value
    result = verify_rules
    return unless result.try(:errors)
    errors.merge!(result.errors)
  end

  def type_rules
    send("#{type.downcase}_rules")
  end

  def verify_rules
    rules = type_rules
    return errors.merge!(value: 'Invalid type') unless rules.class == Gate::Guard
    rules.verify(value)
  end

  def attribute_type(name)
    Account.current.employee_attribute_definitions.where(name: name).first.try(:attribute_type)
  end
end
