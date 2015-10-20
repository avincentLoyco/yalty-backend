class UpdateEvent
  include EmployeeAttributeVersionRules
  attr_reader :versions, :action, :employee, :event, :employee_attributes

  def initialize(attributes, action)
    @versions = []
    @action = action
    @employee = find_employee(attributes)
    @event = find_event(attributes)
    # @employee_attributes = employee_attributes()
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
          version.save!
        end
      rescue
        raise ActiveRecord::Rollback
      end
    end
  end

  def find_employee(attributes)
    if attributes[:employee].try([], :id)
      Account.current.employees.find(attributes[:id])
    end
  end

  def find_event(attributes)
    Account.current.employee_events.find(attributes[:id])
  end

  def employee_attributes(attributes)
    if attributes
      attributes.each do |attribute|
        verify(attribute) do |result|
        end
      end
    end
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
