class ManageEmployeeBalanceRemoval
  attr_reader :new_date, :resource, :current_date

  def initialize(new_date, resource, current_date = resource.validity_date)
    @new_date = find_new_date(new_date)
    @resource = resource
    @current_date = current_date
  end

  def call
    return if resource.time_off_policy.counter? || validity_date_didnt_changed?
    new_date.blank? ? unassign_from_removal : create_or_assign_to_new_removal
  end

  private

  def find_new_date(new_date)
    return unless new_date.present?
    return new_date if new_date.is_a?(Time)
    Time.zone.parse(new_date).utc
  end

  def unassign_from_removal
    resource_removal = resource.balance_credit_removal
    return unless resource_removal
    resource.update!(balance_credit_removal_id: nil)
    resource_removal.destroy! if resource_removal.reload.balance_credit_additions.blank?
  end

  def create_or_assign_to_new_removal
    resource_removal = resource.balance_credit_removal
    new_removal = find_or_create_new_removal
    new_removal.balance_credit_additions << resource
    new_removal.save
    return unless resource_removal
    resource_removal.destroy! if resource_removal.balance_credit_additions.count.zero?
  end

  def find_or_create_new_removal
    new_removal =
      Employee::Balance
      .removal_at_date(resource.employee_id, resource.time_off_category_id, new_date)
    new_removal.first_or_create do |removal|
      removal.effective_at = new_date
      removal.balance_type = 'removal'
    end
  end

  def validity_date_didnt_changed?
    (new_date.blank? && current_date.blank?) ||
      ((new_date.present? && resource.balance_credit_removal.try(:effective_at).eql?(new_date)) &&
      new_date.try(:to_date).eql?(current_date.try(:to_date)))
  end
end
