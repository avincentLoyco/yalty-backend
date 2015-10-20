class CreateEvent
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
          version.event = event
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
        version = set_version(result)
        version.value = result[:value]
        versions.push version
      end
    end
  end

  def set_version(attributes)
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
    result = gate_rules.verify(attribute.deep_symbolize_keys)
    if result.valid? && value_valid?(result.attributes)
      yield(result.attributes)
    else
      raise ActiveRecord::RecordNotFound
    end
  end

  def value_valid?(attributes)
    return true unless attributes.key?(:id) && attributes[:value].to_s != "nil"
  end

  def gate_rules
    Gate.rules do
      required :attribute_name
      required :value
      optional :id
    end
  end
end
