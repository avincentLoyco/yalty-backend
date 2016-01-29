class EmployeeTimeOffPolicy < ActiveRecord::Base
  belongs_to :employee
  belongs_to :time_off_policy

  validates :employee_id, :time_off_policy_id, presence: true
  validates :time_off_policy_id, uniqueness: { scope: :employee_id }

  scope :affected_employees, ->  (policy_id) {
    where(time_off_policy_id: policy_id).pluck(:employee_id)
  }
end
