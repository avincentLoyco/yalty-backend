class UpdateEvent
  include API::V1::Exceptions
  attr_reader :employee_params, :attributes_params, :event_params, :versions,
    :event, :employee

  def initialize(params, employee_attributes_params)
    @versions           = []
    @employee_params    = params[:employee].tap { |attr| attr.delete(:employee_attributes) }
    @attributes_params  = employee_attributes_params
    @event_params       = build_event_params(params)
  end

  def call
    ActiveRecord::Base.transaction do
      find_and_update_event
      find_employee
      manage_versions

      save!
    end
  end

  private

  def build_event_params(params)
    params.tap { |attr| attr.delete(:employee) && attr.delete(:employee_attributes) }
  end

  def find_employee
    @employee = Account.current.employees.find(employee_params[:id])
    working_place_id = employee_params[:working_place_id]
    @employee.working_place_id = working_place_id if working_place_id.present?
  end

  def find_and_update_event
    @event = Account.current.employee_events.find(event_params[:id])
    @event.attributes = event_params
  end

  def manage_versions
    attributes_params.each do |attribute|
      if attribute[:id].present?
        update_version(attribute)
      else
        new_version(attribute)
      end
    end
    remove_absent_versions

    event.employee_attribute_versions = versions
  end

  def update_version(attribute)
    version = event.employee_attribute_versions.find(attribute[:id])
    version.attribute_definition = definition_for(attribute)
    version.value = attribute[:value]
    version.order = attribute[:order]
    @versions << version
  end

  def new_version(attribute)
    version = build_version(attribute)
    if version.attribute_definition_id.present?
      version.value = attribute[:value]
      version.multiple = version.attribute_definition.multiple
    end
    @versions << version
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
    definition = versions.map do |version|
      version.attribute_definition_id unless version.multiple
    end.compact
    definition.size == definition.uniq.size
  end

  def remove_absent_versions
    return unless event.employee_attribute_versions.size > versions.size
    versions_to_remove = event.employee_attribute_versions - versions
    versions_to_remove.map(&:destroy!)
  end

  def attribute_version_valid?
    !event.employee_attribute_versions.map(&:valid?).include?(false)
  end

  def valid?
    event.valid? && employee.valid? && unique_attribute_versions? && attribute_version_valid?
  end

  def save!
    if valid?
      event.save!
      employee.save!
      event.employee_attribute_versions.each(&:save!)

      event
    else
      messages = {}
      messages = messages.merge(employee_attributes: 'Not unique') unless unique_attribute_versions?
      messages = messages
        .merge(event.errors.messages)
        .merge(employee.errors.messages)
        .merge(attribute_versions_errors)

      fail InvalidResourcesError.new(event, messages)
    end
  end

  def attribute_versions_errors
    errors = event.employee_attribute_versions.map do |attr|
      return {} unless attr.attribute_definition
      { attr.attribute_definition.name => attr.data.errors.messages.values }
    end
    errors.reduce({}, :merge).delete_if { |key, value| value.empty? }
  end
end
