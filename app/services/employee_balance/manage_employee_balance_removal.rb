class ManageEmployeeBalanceRemoval
  attr_reader :new_date, :resource, :current_date

  def initialize(new_date, resource, current_date = resource.validity_date)
    @new_date = new_date.try(:to_date)
    @resource = resource
    @current_date = current_date
  end

  def call
    return unless !resource.time_off_policy.counter? && validity_date_changed?
    new_date.blank? || moved_to_future? ? unassign_from_removal : create_or_assign_to_new_removal
  end

  private

  def unassign_from_removal
    resource_removal = resource.balance_credit_removal
    return unless resource_removal
    if resource_removal.balance_credit_additions.count > 1
      resource.update!(balance_credit_removal_id: nil)
    else
      resource_removal.destroy!
    end
  end

  def create_or_assign_to_new_removal
    resource_removal = resource.balance_credit_removal
    new_removal = find_or_create_new_removal
    new_removal.balance_credit_additions << resource
    return unless resource_removal
    resource_removal.destroy! if resource_removal.balance_credit_additions.count == 0
  end

  def find_or_create_new_removal
    new_removal =
      Employee::Balance
      .removal_at_date(resource.employee_id, resource.time_off_category_id, new_date)

    new_removal.first_or_create do |removal|
      removal.effective_at = new_date
    end
  end

  def validity_date_changed?
    ((new_date.blank? || moved_to_past? || moved_to_future?)) || new_date != current_date
  end

  def moved_to_past?
    (current_date.blank? || current_date.to_date > Time.zone.today) && new_date <= Time.zone.today
  end

  def moved_to_future?
    new_date > Time.zone.today
  end
end
