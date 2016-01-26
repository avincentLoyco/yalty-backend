class EmployeeTimeOffPolicy < ActiveRecord::Base
  belongs_to :employee
  belongs_to :time_off_policy

  validates :employee_id, :time_off_policy_id, presence: true
end
