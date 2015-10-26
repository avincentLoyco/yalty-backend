class CreateEvent
  include EmployeeAttributeVersionRules
  include API::V1::Exceptions
  attr_reader :employee_params, :attributes_params, :event_params, :employee, :event, :versions

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
      find_or_build_employee
      build_event
      build_versions

      event.save

      event
    end
  end

  private

  def find_or_build_employee
    if employee_params.key?(:id)
      @employee = Account.current.employees.find(employee_params[:id])
    else
      @employee = Account.current.employees.new
    end
  end

  def build_event
    @event = employee.events.new(event_params)
  end

  def build_versions
    attributes_params.each do |attribute|
      verify(attribute) do |result|
        version = build_version(result)
        version.value = result[:value]
        @versions << version
      end
    end

    event.employee_attribute_versions = @versions
  end

  def build_version(version)
    event.employee_attribute_versions.new(
      employee: employee,
      attribute_definition: definition_for(version)
    )
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
    return true unless (attributes.key?(:id) && !attributes[:value].nil? )
  end

  def definition_for(attribute)
    Account.current.employee_attribute_definitions.find_by!(name: attribute[:attribute_name])
  end
end
