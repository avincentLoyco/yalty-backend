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

  def previous_time_off_policy(category_id)
    employee_policy = previous_time_off_policy_in_category(category_id)
    return employee_policy if employee_policy
    working_place.previous_time_off_policy_in_category(category_id)
  end

  def active_presence_policy
    return presence_policy if presence_policy.present?
    working_place.presence_policy
  end

  def active_holiday_policy
    return holiday_policy if holiday_policy.present?
    working_place.holiday_policy
  end

  def active_policy_in_category(category_id)
    employee_policy = active_time_off_policy_in_category(category_id)
    return employee_policy if employee_policy
    working_place.active_time_off_policy_in_category(category_id)
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

  def time_off_policies_in_category(category_id)
    employee_time_off_policies.assigned
                              .joins(:time_off_policy)
                              .where(time_off_policies: { time_off_category_id: category_id })
                              .order(effective_at: :desc)
  end

  def previous_time_off_policy_in_category(category_id)
    time_off_policies_in_category(category_id).second.try(:time_off_policy)
  end

  def active_time_off_policy_in_category(category_id)
    time_off_policies_in_category(category_id).first.try(:time_off_policy)
  end
end
