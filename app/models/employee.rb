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

  def active_policy_in_category(category_id)
    employee_policy = time_off_policy_in_category(category_id)
    return employee_policy if employee_policy
    working_place.time_off_policy_in_category(category_id)
  end

  def last_balance_in_category(category_id)
    employee_balances.where(time_off_category_id: category_id).order('effective_at').last
  end

  def unique_balances_categories
    time_off_categories.distinct
  end

  private

  def time_off_policy_in_category(category_id)
    employee_time_off_policies.joins(:time_off_policy)
      .find_by(time_off_policies: { time_off_category_id: category_id }).try(:time_off_policy)
  end
end
