class CreateEvent
  include EmployeeAttributeVersionRules
  include API::V1::Exceptions
  attr_reader :employee, :employee_attributes, :event, :versions

  def initialize(attributes)
    @versions = []
    @employee = find_or_initialize_employee(attributes[:employee])
    @event = init_event(attributes)
    @employee_attributes = employee_attributes(attributes[:employee][:employee_attributes])
  end

  def call
    save_records
    event
  end

  private

  def save_records
    ActiveRecord::Base.transaction do
      begin
        employee.save!
        versions.each do |version|
          version.event = event if event.persisted?
          version.employee = employee
          version.save!
        end
      rescue
        raise ActiveRecord::Rollback
      end
    end
  end

  def find_or_initialize_employee(attributes)
    if attributes.key?(:id)
      Account.current.employees.find(attributes[:id])
    else
      Account.current.employees.new
    end
  end

  def init_event(attributes)
    employee.events.new(attributes.except(:employee))
  end

  def employee_attributes(attributes)
    attributes.each do |attribute|
      verify(attribute) do |result|
        version = find_or_initialize_version(result)
        version.value = result[:value]
        versions.push version
      end
    end
  end

  def find_or_initialize_version(attributes)
    if attributes.key?(:id)
      employee.employee_attribute_versions.find(attributes[:id])
    else
      Employee::AttributeVersion.new(attribute_definition: set_definition(attributes))
    end
  end

  def set_definition(attributes)
    Account.current.employee_attribute_definitions.find_by!(name: attributes[:attribute_name])
  end

  def verify(attribute)
    result = gate_rules('POST').verify(attribute.deep_symbolize_keys)
    if result.valid? && value_valid?(result.attributes)
      yield(result.attributes)
    else
      fail MissingOrInvalidData.new(set_exception(result)), 'Missing or Invalid Data'
    end
  end

  def set_exception(result)
    result.errors.any? ? result.errors : 'Invalid Value for Attribute'
  end

  def value_valid?(attributes)
    return true unless (attributes.key?(:id) && attributes[:value] != nil)
  end
end
