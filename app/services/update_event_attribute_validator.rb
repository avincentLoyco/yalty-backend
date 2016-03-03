class UpdateEventAttributeValidator
  attr_reader :employee_attributes, :event_unauthorized_attributes, :resource,
    :event_unauthorized_attributes_ids

  def initialize(employee_attributes, resource)
    @employee_attributes = employee_attributes
    @resource = resource
    @event_unauthorized_attributes = resource.employee_attribute_versions.not_editable
    @event_unauthorized_attributes_ids = @event_unauthorized_attributes.pluck(:id)
  end

  def call
    employee_attributes.each do |employee_attribute|
      next unless
        ActsAsAttribute::NOT_EDITABLE_ATTRIBUTES_FOR_EMPLOYEE
        .include?(employee_attribute[:attribute_name])
      verify_if_not_new(employee_attribute[:id])
      verify_attr_exist_in_event(employee_attribute[:id])
      verify_if_not_changed(employee_attribute)
    end
  end

  private

  def verify_if_not_changed(employee_attribute)
    current_attribute_value = event_unauthorized_attributes.find(employee_attribute[:id]).data.value
    unauthorized_attribute_handling unless employee_attribute[:value] == current_attribute_value
  end

  def verify_if_not_new(employee_attribute_id)
    unauthorized_attribute_handling unless employee_attribute_id
  end

  def verify_attr_exist_in_event(employee_attribute_id)
    unauthorized_attribute_handling unless
      event_unauthorized_attributes_ids.include?(employee_attribute_id)
  end

  def unauthorized_attribute_handling
    raise CanCan::AccessDenied.new('Not authorized!', :update, Employee)
  end
end
