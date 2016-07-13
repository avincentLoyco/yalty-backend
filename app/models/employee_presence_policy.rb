class EmployeePresencePolicy < ActiveRecord::Base
  attr_accessor :effective_till

  belongs_to :employee
  belongs_to :presence_policy

  validates :employee_id, :presence_policy_id, :effective_at, presence: true
  validates :effective_at, uniqueness: { scope: [:employee_id, :presence_policy_id] }
  validate :no_balances_after_effective_at, on: :create, if: :employee_id
  validates :order_of_start_day, numericality: { greater_than: 0 }
  validate :presence_days_presence, if: :presence_policy
  validate :order_smaller_than_last_presence_day_order, if: [:presence_policy, :order_of_start_day]

  private

  def presence_days_presence
    return unless presence_policy.presence_days.blank?
    errors.add(:presence_policy, 'Must have presence_days assigned')
  end

  def order_smaller_than_last_presence_day_order
    max_order = presence_policy.presence_days.pluck(:order).max
    return unless max_order.present? && order_of_start_day > max_order
    errors.add(:order_of_start_day, 'Must be smaller than last presence day order')
  end

  def no_balances_after_effective_at
    balances_after_effective_at =
      employee
      .employee_balances.where('effective_at >= ? AND time_off_id IS NOT NULL', effective_at)
    return unless balances_after_effective_at.any?
    errors.add(:effective_at, 'Employee balance after effective at already exists')
  end
end
