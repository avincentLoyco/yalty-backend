class VerifyEmployeeAttributeValues
  include Attributes::PersonSchema, Attributes::StringSchema, Attributes::NumberSchema,
    Attributes::AddressSchema, Attributes::BooleanSchema, Attributes::ChildSchema,
    Attributes::CurrencySchema, Attributes::DateSchema, Attributes::LineSchema,
    Attributes::FileSchema

  attr_reader :value, :errors, :type

  def initialize(employee_attribute)
    @value = employee_attribute.select { |k, _v| k.to_s == "value" }
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
    result = verify_schema
    return unless result.try(:errors).present?
    errors.merge!(result.messages)
  end

  def type_schema
    send("#{type.downcase}_schema")
  end

  def verify_schema
    schema = type_schema
    return errors.merge!(value: "Invalid type") if schema.nil?
    schema.call(value)
  end

  def attribute_type(name)
    Account.current.employee_attribute_definitions.where(name: name).first.try(:attribute_type)
  end
end
