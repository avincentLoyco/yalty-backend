class EmployeeTimeOffPolicy < ActiveRecord::Base
  belongs_to :employee
  belongs_to :time_off_policy

  validates :employee_id, :time_off_policy_id, :effective_at, presence: true
  validates :time_off_policy_id, uniqueness: { scope: [:employee_id, :effective_at] }
  validate :effective_at_newer_than_previous_start_date, if: [:time_off_policy, :effective_at]

  scope :affected_employees, lambda { |policy_id|
    where(time_off_policy_id: policy_id).pluck(:employee_id)
  }

  scope :assigned, -> { where(['effective_at <= ?', Date.tomorrow]) }

  private

  def effective_at_newer_than_previous_start_date
    category_id = time_off_policy.time_off_category_id
    active_policy = employee.active_policy_in_category(category_id)
    return unless active_policy && active_policy.previous_period.first > effective_at.to_date
    errors.add(:effective_at, 'Must be after current policy previous perdiod start date')
  end
end
