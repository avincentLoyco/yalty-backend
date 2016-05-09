class Employee < ActiveRecord::Base
  belongs_to :account, inverse_of: :employees, required: true
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
  has_many :employee_working_places
  has_many :working_places, through: :employee_working_places

  validates :employee_working_places, length: { minimum: 1 }

  def active_policy_in_category_at_date(category_id, date = Time.zone.today)
    assigned_time_off_policies_in_category(category_id, date).first
  end

  def active_presence_policy
    # TODO, Method to change after adding employee_presence_policy
    #       except adding join model we should receive date param (as in holiday policy)
    return presence_policy if presence_policy.present?
    active_working_place_at.presence_policy
  end

  def active_holiday_policy_at(date)
    return holiday_policy if holiday_policy.present?
    active_working_place_at(date).holiday_policy
  end

  def active_working_place_at(date = Time.zone.now)
    employee_working_places
      .where('effective_at <= ?', date)
      .order(:effective_at)
      .last
      .try(:working_place)
  end

  def last_balance_in_category(category_id)
    employee_balances.where(time_off_category_id: category_id).order('effective_at').last
  end

  def unique_balances_categories
    time_off_categories.distinct
  end

  def assigned_time_off_policies_in_category(category_id, date = Time.zone.now)
    EmployeeTimeOffPolicy.assigned_at(date).by_employee_in_category(id, category_id).limit(3)
  end

  def not_assigned_time_off_policies_in_category(category_id, date = Time.zone.now)
    EmployeeTimeOffPolicy.not_assigned_at(date).by_employee_in_category(id, category_id).limit(2)
  end
end
