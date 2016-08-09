class EmployeeWorkingPlace < ActiveRecord::Base
  include ValidateEffectiveAtBeforeHired

  attr_accessor :effective_till

  belongs_to :employee
  belongs_to :working_place

  validates :employee, :working_place, :effective_at, presence: true
  validates :effective_at, uniqueness: { scope: [:employee_id, :working_place_id] }
  validate :effective_at_cant_be_before_start_date, if: [:employee, :effective_at]
  validate :no_balances_after_effective_at, if: [:employee, :effective_at]

  private

  def no_balances_after_effective_at
    older = effective_at_was && effective_at_was < effective_at ? effective_at_was : effective_at
    balances_after_effective_at =
      employee
      .employee_balances.where('effective_at >= ? AND time_off_id IS NOT NULL', older)

    return unless balances_after_effective_at.present?
    errors.add(:effective_at, 'Employee balance after effective at already exists')
  end
end
