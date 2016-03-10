class EmployeeTimeOffPolicy < ActiveRecord::Base
  belongs_to :employee
  belongs_to :time_off_policy

  validates :employee_id, :time_off_policy_id, :effective_at, presence: true
  validates :time_off_policy_id, uniqueness: { scope: [:employee_id, :effective_at] }

  scope :affected_employees, lambda { |policy_id|
    where(time_off_policy_id: policy_id).pluck(:employee_id)
  }

  scope :assigned, -> { where(['effective_at <= ?', Date.tomorrow]) }
end
