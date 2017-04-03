class UpdateEventAttributeValidator
  attr_reader :employee_attributes, :event_unauthorized_attributes, :resource,
    :event_unauthorized_attributes_ids

  def initialize(employee_attributes)
    @employee_attributes = employee_attributes
  end

  def call
    employee_attributes.each do |employee_attribute|
      if ActsAsAttribute::NOT_EDITABLE_ATTRIBUTES_FOR_EMPLOYEE
         .include?(employee_attribute[:attribute_name])
        unauthorized_attribute_handling
      end
    end
  end

  private

  def unauthorized_attribute_handling
    raise CanCan::AccessDenied.new('Not authorized!', :update, Employee)
  end
end
