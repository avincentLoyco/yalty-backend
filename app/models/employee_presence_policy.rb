class EmployeePresencePolicy < ActiveRecord::Base
  attr_accessor :effective_till

  belongs_to :employee
  belongs_to :presence_policy

  validates :employee_id, :presence_policy_id, :effective_at, presence: true
  validates :effective_at, uniqueness: { scope: [:employee_id, :presence_policy_id] }
end
