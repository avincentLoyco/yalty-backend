class EmployeePresencePolicy < ActiveRecord::Base
  attr_accessor :effective_till

  belongs_to :employee
  belongs_to :presence_policy

  validates :employee_id, :presence_policy_id, :effective_at, presence: true
  validates :effective_at, uniqueness: { scope: [:employee_id, :presence_policy_id] }
  validate :no_balances_after_effective_at, on: :create, if: :employee_id

  private

  def no_balances_after_effective_at
    balances_after_effective_at =
      employee
      .employee_balances.where('effective_at >= ? AND time_off_id IS NOT NULL', effective_at)
    return unless balances_after_effective_at.any?
    errors.add(:effective_at, 'Employee balance after effective at already exists')
  end
end
