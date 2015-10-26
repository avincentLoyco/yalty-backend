class CreateEvent
  include EmployeeAttributeVersionRules
  include API::V1::Exceptions
  attr_reader :employee_params, :attributes_params, :event_params, :versions, :employee, :event

  def initialize(params)
    @employee          = nil
    @event             = nil
    @versions          = []
    @employee_params   = params[:employee]
    @attributes_params = params[:employee][:employee_attributes]
    @event_params      = params.tap { |attr| attr.delete(:employee) }
  end

  def call
    ActiveRecord::Base.transaction do
      find_or_initialize_employee(employee_params)
      initialize_event(event_params)
      initialize_versions(attributes_params)

      event.employee_attribute_versions = versions
      event.save

      event
    end
  end

  private

  def verify(attribute)
    result = gate_rules('POST').verify(attribute.deep_symbolize_keys)
    if result.valid? && value_valid?(result.attributes)
      yield(result.attributes)
    else
      fail MissingOrInvalidData.new(set_exception(result)), 'Missing or Invalid Data'
    end
  end

  def find_or_initialize_employee(attributes)
    if attributes.key?(:id)
      @employee = Account.current.employees.find(attributes[:id])
    else
      @employee = Account.current.employees.new
    end
  end

  def initialize_event(attributes)
    @event = employee.events.new(attributes)
  end

  def initialize_versions(attributes)
    attributes.each do |attribute|
      verify(attribute) do |result|
        version = initialize_version(result)
        version.value = result[:value]
        versions.push(version)
      end
    end

    versions
  end

  def initialize_version(attributes)
    event.employee_attribute_versions.new(
      employee: employee,
      attribute_definition: set_definition(attributes)
    )
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
