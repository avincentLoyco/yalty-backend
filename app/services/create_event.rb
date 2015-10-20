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
        # two types of attributes: new and existing
          # new -> find definition, push to versions
          # exisiting -> check if valid id and value nil, update, push to versions
        definition = Employee::AttributeDefinition.find_by!(name: result[:attribute_name])
        if result.key?(:id)
          version = Employee::AttributeVersion.find(result[:id])
        else
          version = Employee::AttributeVersion.new(attribute_definition: definition)
        end
        version.value = result[:value]
        versions.push version
      end
    end
  end

  def verify(attribute)
    # write it prettier, move rules outside, add check for vattribute value for create
    rules = Gate.rules do
      required :attribute_name
      required :value
      optional :id
    end
    result = rules.verify(attribute.deep_symbolize_keys)
    if result.valid?
      yield(result.attributes)
    else
      # TODO add better exception
      raise ActiveRecord::RecordNotFound
    end
  end
end
