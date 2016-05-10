class CreateEvent
  include API::V1::Exceptions
  attr_reader :employee_params, :attributes_params, :event_params, :employee,
    :event, :versions

  def initialize(params, employee_attributes_params)
    @employee          = nil
    @event             = nil
    @versions          = []
    @employee_params   = params[:employee]
    @attributes_params = employee_attributes_params
    @event_params      = build_event_params(params)
  end

  def call
    ActiveRecord::Base.transaction do
      build_event
      find_or_build_employee
      build_versions

      save!
    end
  end

  private

  def build_event_params(params)
    params.tap { |attr| attr.delete(:employee) && attr.delete(:employee_attributes) }
  end

  def find_or_build_employee
    if employee_params.key?(:id)
      @employee = Account.current.employees.find(employee_params[:id])
      working_place_id = employee_params[:working_place_id]
      @employee.working_place_id = working_place_id if working_place_id.present?
    else
      @employee = Account.current.employees.new(employee_params)
      employee.events << [event]
    end

    event.employee = @employee
  end

  def build_event
    @event = Account.current.employee_events.new(event_params)
  end

  def build_versions
    attributes_params.each do |attribute|
      version = build_version(attribute)
      if version.attribute_definition_id.present?
        version.value = attribute[:value]
        version.multiple = version.attribute_definition.multiple
      end
      @versions << version
    end

    event.employee_attribute_versions = versions
  end

  def build_version(version)
    event.employee_attribute_versions.new(
      employee: employee,
      attribute_definition: definition_for(version),
      order: version[:order]
    )
  end

  def definition_for(attribute)
    Account.current.employee_attribute_definitions.find_by(name: attribute[:attribute_name])
  end

  def unique_attribute_versions?
    definition = event.employee_attribute_versions.map do |version|
      version.attribute_definition_id unless version.multiple
    end.compact

    definition.size == definition.uniq.size
  end

  def save!
    if event.valid? && employee.valid? && unique_attribute_versions?
      event.save!
      employee.save!

      event
    else
      messages = {}
      messages = messages.merge(employee_attributes: 'Not unique') unless unique_attribute_versions?
      messages = messages
                 .merge(event.errors.messages)
                 .merge(employee.errors.messages)
                 .merge(attribute_versions_errors)

      raise InvalidResourcesError.new(event, messages)
    end
  end

  def attribute_versions_errors
    errors = event.employee_attribute_versions.map do |attr|
      return {} unless attr.attribute_definition
      { attr.attribute_definition.name => attr.data.errors.messages.values }
    end
    errors.reduce({}, :merge).delete_if { |_key, value| value.empty? }
  end
end
