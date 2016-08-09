class EmployeePresencePolicy < ActiveRecord::Base
  include ActsAsIntercomTrigger
  include ValidateEffectiveAtBeforeHired

  attr_accessor :effective_till

  belongs_to :employee
  belongs_to :presence_policy

  validates :employee_id, :presence_policy_id, :effective_at, presence: true
  validates :effective_at, uniqueness: { scope: [:employee_id, :presence_policy_id] }
  validate :no_balances_after_effective_at, if: [:employee_id, :effective_at]
  validates :order_of_start_day, numericality: { greater_than: 0 }
  validate :presence_days_presence, if: :presence_policy
  validate :order_smaller_than_last_presence_day_order, if: [:presence_policy, :order_of_start_day]

  def order_for(date)
    order_difference = ((date - effective_at) % policy_length).to_i
    new_order = order_of_start_day + order_difference
    if new_order > policy_length
      new_order - policy_length
    else
      new_order
    end
  end

  def policy_length
    return 0 unless presence_policy.presence_days.present?
    presence_policy.presence_days.pluck(:order).max
  end

  private

  def presence_days_presence
    return unless presence_policy.presence_days.blank?
    errors.add(:presence_policy, 'Must have presence_days assigned')
  end

  def order_smaller_than_last_presence_day_order
    return unless policy_length != 0 && order_of_start_day > policy_length
    errors.add(:order_of_start_day, 'Must be smaller than last presence day order')
  end

  def no_balances_after_effective_at
    older = effective_at_was && effective_at_was < effective_at ? effective_at_was : effective_at
    balances_after_effective_at =
      employee
      .employee_balances.where('effective_at >= ? AND time_off_id IS NOT NULL', older)

    return unless balances_after_effective_at.present?
    errors.add(:effective_at, 'Employee balance after effective at already exists')
  end
end
