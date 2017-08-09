class EmployeePresencePolicy < ActiveRecord::Base
  include ActsAsIntercomTrigger
  include ValidateEffectiveAtBetweenHiredAndContractEndDates

  attr_accessor :effective_till

  belongs_to :employee
  belongs_to :presence_policy

  validates :employee_id, :presence_policy_id, :effective_at, presence: true
  validates :effective_at, uniqueness: { scope: [:employee_id, :presence_policy_id] }
  validates :order_of_start_day, numericality: { greater_than: 0 }
  validates :occupation_rate,
    numericality: { less_than_or_equal_to: 1, greater_than_or_equal_to: 0 }
  validate :presence_days_presence, if: -> { presence_policy.present? && !presence_policy.reset }
  validate :order_smaller_than_last_presence_day_order, if: [:presence_policy, :order_of_start_day]

  scope :with_reset, -> { joins(:presence_policy).where(presence_policies: { reset: true }) }
  scope :not_reset, -> { joins(:presence_policy).where(presence_policies: { reset: false }) }
  scope :assigned_since, ->(date) { where('effective_at >= ?', date) }

  alias related_resource presence_policy

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
end
