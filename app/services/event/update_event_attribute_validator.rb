class UpdateEventAttributeValidator
  attr_reader :employee_attributes, :event_unauthorized_attributes, :resource,
    :event_unauthorized_attributes_ids

  def initialize(employee_attributes)
    @employee_attributes = employee_attributes
  end

  def call
    return if employee_attributes.nil?
    employee_attributes.each do |employee_attribute|
      next if attribute_editable_for_employee?(employee_attribute) &&
          can_assign_file?(employee_attribute)

      unauthorized_attribute_handling
    end
  end

  private

  def attribute_editable_for_employee?(employee_attribute)
    return true if Account::User.current.owner_or_administrator?
    ActsAsAttribute::NOT_EDITABLE_ATTRIBUTES_FOR_EMPLOYEE
      .exclude?(employee_attribute[:attribute_name])
  end

  def attribute_is_file?(employee_attribute)
    Account::DEFAULT_ATTRIBUTES["File"].include?(employee_attribute[:attribute_name])
  end

  def unauthorized_attribute_handling
    raise CanCan::AccessDenied.new("Not authorized!", :update, Employee)
  end

  def can_assign_file?(employee_attribute)
    return true unless attribute_is_file?(employee_attribute)
    employee_attribute[:value].nil? ||
      Account.current.available_modules.include?("filevault") ||
      employee_attribute[:attribute_name].eql?("profile_picture")
  end
end
