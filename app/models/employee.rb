class Employee < ActiveRecord::Base
  belongs_to :account, inverse_of: :employees, required: true
  belongs_to :working_place, inverse_of: :employees
  belongs_to :holiday_policy
  belongs_to :presence_policy
  belongs_to :user, class_name: 'Account::User'
  has_many :employee_attribute_versions,
    class_name: 'Employee::AttributeVersion',
    inverse_of: :employee
  has_many :employee_attributes,
    class_name: 'Employee::Attribute',
    inverse_of: :employee
  has_many :events, class_name: 'Employee::Event', inverse_of: :employee
  has_many :time_offs
  has_many :employee_balances, class_name: 'Employee::Balance'
  has_many :employee_time_off_policies
  has_many :time_off_policies, through: :employee_time_off_policies
  has_many :time_off_categories, through: :employee_balances

  validates :working_place_id, presence: true

  def last_effective_at(category_id)
    time_off_policies_in_category(category_id).first.try(:effective_at)
  end

  def last_balance_addition_in_category(category_id)
    employee_balances.where(
      time_off_category_id: category_id,
      policy_credit_addition: true,
      time_off_policy: previous_related_time_off_policy(category_id).try(:time_off_policy)
    )
                     .order(effective_at: :desc).first
  end

  def previous_start_date(category_id)
    current_policy_previous_start = active_related_time_off_policy(category_id).previous_start_date
    if active_related_time_off_policy(category_id).effective_at > current_policy_previous_start &&
        previous_related_time_off_policy(category_id)
      previous_related_time_off_policy(category_id).last_start_date
    else
      current_policy_previous_start
    end
  end

  def current_policy_period(category_id)
    (current_start_date(category_id)..current_end_date(category_id))
  end

  def previous_policy_period(category_id)
    (previous_start_date(category_id)..current_start_date(category_id))
  end

  def previous_related_time_off_policy(category_id)
    assigned_time_off_policies_in_category(category_id).second
  end

  def active_related_time_off_policy(category_id)
    assigned_time_off_policies_in_category(category_id).first
  end

  def active_policy_in_category(category_id)
    assigned_time_off_policies_in_category(category_id).first.try(:time_off_policy)
  end

  def active_presence_policy
    return presence_policy if presence_policy.present?
    working_place.presence_policy
  end

  def active_holiday_policy
    return holiday_policy if holiday_policy.present?
    working_place.holiday_policy
  end

  def last_balance_in_category(category_id)
    employee_balances.where(time_off_category_id: category_id).order('effective_at').last
  end

  def unique_balances_categories
    time_off_categories.distinct
  end

  def first_balance_in_policy(policy_id)
    employee_balances.where(time_off_policy_id: policy_id).order(effective_at: :asc).first
  end

  private

  def assigned_time_off_policies_in_category(category_id)
    from_employee = EmployeeTimeOffPolicy.assigned.by_employee_in_category(id, category_id).limit(3)
    return from_employee if from_employee.size > 3
    from_working_place = WorkingPlaceTimeOffPolicy.assigned.by_working_place_in_category(
      working_place_id, category_id).limit(3)
    from_employee + from_working_place
  end

  def future_related_time_off_policy(category_id)
    employee_policies = EmployeeTimeOffPolicy.by_employee_in_category(id, category_id)
    return employee_policies.not_assigned.last if employee_policies.present?
    WorkingPlaceTimeOffPolicy.assigned.by_working_place_in_category(
      working_place_id, category_id).last
  end

  def current_start_date(category_id)
    newest = assigned_time_off_policies_in_category(category_id).first.try(:time_off_policy).start_date
    return newest if newest <= Time.zone.today
    time_off_policies_in_category(category_id).second.try(:start_date)
  end

  def current_end_date(category_id)
    active_end_date = active_related_time_off_policy(category_id).try(:end_date)
    future_start_date = future_related_time_off_policy(category_id).try(:end_date)
    active_end_date < future_start_date ? active_end_date : future_start_date
  end
end
