class CreateEvent
  attr_reader :employee_params, :attributes_params, :event_params, :employee,
    :event, :versions

  def initialize(params, employee_attributes_params)
    @employee          = nil
    @event             = nil
    @versions          = []
    @employee_params   = params[:employee]
    @attributes_params = employee_attributes_params
    @event_params      = params.tap { |attr| attr.delete(:employee) }
  end

  def call
    ActiveRecord::Base.transaction do
      build_event
      find_or_build_employee
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

    event.employee = @employee
  end

  def build_event
    @event = Account.current.employee_events.new(event_params)
  end

  def build_versions
    attributes_params.each do |attribute|
      version = build_version(attribute)
      version.value = attribute[:value] if version.attribute_definition_id.present?
      @versions << version
    end

    event.employee_attribute_versions << versions
  end

  def build_version(version)
    event.employee_attribute_versions.new(
      employee: employee,
      attribute_definition: definition_for(version)
    )
  end

  def definition_for(attribute)
    Account.current.employee_attribute_definitions.find_by(name: attribute[:attribute_name])
  end
end
