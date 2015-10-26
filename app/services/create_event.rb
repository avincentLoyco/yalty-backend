class CreateEvent
  include EmployeeAttributeVersionRules
  include API::V1::Exceptions
  attr_reader :employee_params, :attributes_params, :event_params, :versions

  def initialize(params)
    @versions          = []
    @employee_params   = params[:employee]
    @attributes_params = params[:employee][:employee_attributes]
    @event_params      = params.tap { |attr| attr.delete(:employee) }
  end

  def call
    ActiveRecord::Base.transaction do
      event = Account.current.employee_events.new(event_params)
      employee = find_or_initialize_employee(employee_params)
      event.employee = employee
      employee_attributes(attributes_params, employee)
      ver = versions.map do |version|
        version.employee = employee
        version
      end
      event.employee_attribute_versions = ver
      event.save
      event
    end
  end

  def employee_attributes(attributes, employee)
    attributes.each do |attribute|
      verify(attribute) do |result|
        version = find_or_initialize_version(result, employee)
        version.value = result[:value]
        versions.push version
      end
    end
  end

  def verify(attribute)
    result = gate_rules('POST').verify(attribute.deep_symbolize_keys)
    if result.valid? && value_valid?(result.attributes)
      yield(result.attributes)
    else
      fail MissingOrInvalidData.new(set_exception(result)), 'Missing or Invalid Data'
    end
  end

  def find_or_initialize_version(attributes, employee)
    if attributes.key?(:id)
      employee.employee_attribute_versions.find(attributes[:id])
    else
      Employee::AttributeVersion.new(attribute_definition: set_definition(attributes))
    end
  end

  def find_or_initialize_employee(attributes)
    if attributes.key?(:id)
      Account.current.employees.find(attributes[:id])
    else
      Account.current.employees.new
    end
  end

  def set_exception(result)
    result.errors.any? ? result.errors : 'Invalid Value for Attribute'
  end

  def value_valid?(attributes)
    return true unless (attributes.key?(:id) &&  !attributes[:value].nil? )
  end

  def set_definition(attributes)
    Account.current.employee_attribute_definitions.find_by!(name: attributes[:attribute_name])
  end
end
