require 'employee_policy_period'

class EmployeeTimeOffPolicy < ActiveRecord::Base
  belongs_to :employee
  belongs_to :time_off_policy
  belongs_to :time_off_category

  validates :employee_id, :time_off_policy_id, :effective_at, presence: true
  validates :effective_at, uniqueness: { scope: [:employee_id, :time_off_policy_id] }

  delegate :end_month, :end_day, to: :time_off_policy

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
