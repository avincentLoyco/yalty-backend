class UpdateEvent
  include EmployeeAttributeVersionRules
  include API::V1::Exceptions
  attr_reader :employee_params, :attributes_params, :event_params, :versions, :action

  def initialize(params, action)
    @versions           = []
    @action             = action
    @employee_params    = params[:employee]
    @attributes_params  = params[:employee].try(:[], :employee_attributes)
    @event_params       = params.tap { |attr| attr.delete(:employee) }
  end

  def call
    ActiveRecord::Base.transaction do
      event = find_and_update_event(event_params)
      employee = find_employee(employee_params)
      employee_attributes(attributes_params, event)
      remove_absent_versions(event)
      ver = versions.map do |version|
        version.employee = employee
        version.save
        version
      end
      event.employee_attribute_versions = ver
      event.save
      event
    end
  end

  private

  def find_employee(attributes)
    if attributes.try(:[], :id)
      Account.current.employees.find(attributes[:id])
    end
  end

  def find_and_update_event(attributes)
    event = Account.current.employee_events.find(attributes[:id])
    event.attributes = attributes
    event
  end

  def employee_attributes(attributes, event)
    if attributes
      attributes.each do |attribute|
        verify(attribute) do |result|
          version = event.employee_attribute_versions.find(result[:id])
          version.value = result[:value]
          versions.push(version)
        end
      end
    end
  end

  def remove_absent_versions(event)
    if event.employee_attribute_versions.size > versions.size
      versions_to_remove = event.employee_attribute_versions - versions
      versions_to_remove.map &:destroy!
    end
  end

  def verify(attribute)
    result = gate_rules(action).verify(attribute.deep_symbolize_keys)
    if result.valid?
      yield(result.attributes)
    else
      fail MissingOrInvalidData.new(result.errors), 'Missing or Invalid Data'
    end
  end
end
