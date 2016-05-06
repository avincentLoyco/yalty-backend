require 'employee_policy_period'

class EmployeeTimeOffPolicy < ActiveRecord::Base
  attr_accessor :effective_till

  belongs_to :employee
  belongs_to :time_off_policy
  belongs_to :time_off_category

  validates :employee_id, :time_off_policy_id, :effective_at, presence: true
  validates :effective_at, uniqueness: { scope: [:employee_id, :time_off_policy_id] }
  validate :no_balances_after_effective_at, on: :create, if: :time_off_policy
  validate :policy_has_minimum_day_period, on: :create, if: :time_off_policy

  before_create :add_category_id

  scope :affected_employees, lambda { |policy_id|
    where(time_off_policy_id: policy_id).pluck(:employee_id)
  }

  scope :not_assigned, -> { where(['effective_at > ?', Time.zone.today]) }
  scope :assigned_at, -> (date) { where(['effective_at <= ?', date]) }
  scope :assigned, -> { where(['effective_at <= ?', Date.tomorrow]) }
  scope :by_employee_in_category, lambda { |employee_id, category_id|
    joins(:time_off_policy)
      .where(time_off_policies: { time_off_category_id: category_id }, employee_id: employee_id)
      .order(effective_at: :desc)
  }

  private

  def no_balances_after_effective_at
    balances_after_effective_at =
      Employee::Balance.employee_balances(employee_id, time_off_policy.time_off_category_id)
                       .where('effective_at >= ?', effective_at)
    return unless balances_after_effective_at.present?
    errors.add(:time_off_category, 'Employee balance after effective at already exists')
  end

  def policy_has_minimum_day_period
    related =
      self
      .class
      .by_employee_in_category(employee_id, time_off_policy.time_off_category_id)
      .where(
        'effective_at between ? and ?',
        effective_at - 1.day + 1.minute, effective_at + 1.day - 1.minute
      )
    errors.add(:effective_at, 'Policy period must last minimum 1 day') if related.present?
  end

  def add_category_id
    self.time_off_category_id = time_off_policy.time_off_category_id
  end

  def effective_at_newer_than_previous_start_date
    category_id = time_off_policy.time_off_category_id
    active_policy = employee.active_related_time_off_policy(category_id)
    return unless active_policy &&
        EmployeePolicyPeriod.new(employee, category_id).previous_start_date > effective_at.to_date
    errors.add(:effective_at, 'Must be after current policy previous perdiod start date')
  end
end
