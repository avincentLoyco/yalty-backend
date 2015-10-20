class UpdateEvent
  include EmployeeAttributeVersionRules
  attr_reader :versions, :action, :employee, :event, :employee_attributes

  def initialize(attributes, action)
    @versions = []
    @action = action
    @employee = find_employee(attributes)
    @event = find_and_update_event(attributes)
    @employee_attributes = employee_attributes(attributes[:employee].try(:[], :employee_attributes))
  end

  def call
    save_records
    event
  end

  private

  def save_records
    ActiveRecord::Base.transaction do
      begin
        event.save!
        versions.each do |version|
          process_version(version)
        end
      rescue
        raise ActiveRecord::Rollback
      end
    end
  end

  def find_employee(attributes)
    if attributes[:employee].try(:[], :id)
      Account.current.employees.find(attributes[:employee][:id])
    end
  end

  def find_and_update_event(attributes)
    event = Account.current.employee_events.find(attributes[:id])
    event.attributes = attributes.except(:id, :employee)
    event
  end

  def employee_attributes(attributes)
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

  def process_version(version)
    version.value == "nil" ? version.destroy! : version.save!
  end

  def verify(attribute)
    result = gate_rules(action).verify(attribute.deep_symbolize_keys)
    if result.valid?
      yield(result.attributes)
    else
      raise ActiveRecord::RecordNotFound
    end
  end
end
