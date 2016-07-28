class ManageEmployeeBalanceRemoval
  attr_reader :new_date, :resource, :current_date

  def initialize(new_date, resource, current_date = resource.validity_date)
    @new_date = new_date.try(:to_date)
    @resource = resource
    @current_date = current_date
  end

  def call
    return unless !resource.time_off_policy.counter? && validity_date_changed?
    if new_date.blank? || moved_to_future?
      resource.balance_credit_removal.try(:destroy!)
    else
      create_removal unless resource.balance_credit_removal.present?
    end
  end

  private

  def validity_date_changed?
    ((new_date.blank? || moved_to_past? || moved_to_future?)) || new_date != current_date
  end

  def moved_to_past?
    (current_date.blank? || current_date.to_date > Time.zone.today) && new_date <= Time.zone.today
  end

  def moved_to_future?
    new_date > Time.zone.today
  end

  def create_removal
    return unless resource.balance_credit_removal.blank?
    category, employee, account, options = params
    CreateEmployeeBalance.new(category, employee, account, options).call
  end

  def params
    [resource.time_off_category_id, resource.employee_id, resource.employee.account_id,
     { policy_credit_removal: true, skip_update: true, balance_credit_addition_id: resource.id,
       effective_at: new_date }]
  end
end
