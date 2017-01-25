require 'employee_policy_period'

class EmployeeTimeOffPolicy < ActiveRecord::Base
  include ActsAsIntercomTrigger
  include ValidateEffectiveAtBetweenHiredAndContractEndDates

  attr_accessor :effective_till

  belongs_to :employee
  belongs_to :time_off_policy
  belongs_to :time_off_category

  validates :employee_id, :time_off_policy_id, :effective_at, presence: true
  validates :effective_at, uniqueness: { scope: [:employee_id, :time_off_category_id] }
  validate :verify_not_change_of_policy_type_in_category, if: [:employee, :time_off_policy]
  validate :no_balances_without_valid_policy, on: :update

  before_save :add_category_id
  before_destroy :balances_without_valid_policy_present?

  scope :not_assigned_at, ->(date) { where(['effective_at > ?', date]) }
  scope :assigned_at, ->(date) { where(['effective_at <= ?', date]) }
  scope :by_employee_in_category, lambda { |employee_id, category_id|
    joins(:time_off_policy)
      .where(time_off_policies: { time_off_category_id: category_id }, employee_id: employee_id)
      .order(effective_at: :desc)
  }
  scope :with_reset, -> { joins(:time_off_policy).where(time_off_policies: { reset: true }) }
  scope :not_reset, -> { joins(:time_off_policy).where(time_off_policies: { reset: false }) }

  def policy_assignation_balance(effective_at = self.effective_at)
    employee
      .employee_balances
      .where(
        time_off_category_id: time_off_policy.time_off_category.id,
        time_off_id: nil
      )
      .where(
        'effective_at = ?', effective_at + Employee::Balance::START_DATE_OR_ASSIGNATION_OFFSET
      )
      .first
  end

  def employee_balances
    if effective_till
      Employee::Balance.employee_balances(employee.id, time_off_category.id)
                       .where('effective_at BETWEEN ? and ?', effective_at, effective_till)
    else
      Employee::Balance.employee_balances(employee.id, time_off_category.id)
                       .where('effective_at >= ?', effective_at)
    end
  end

  def effective_till
    next_effective_at =
      self
      .class
      .by_employee_in_category(employee_id, time_off_category_id)
      .where('effective_at > ?', effective_at)
      .last
      .try(:effective_at)
    next_effective_at - 1.day if next_effective_at
  end

  def previous_policy_for(date = effective_at)
    self
      .class
      .by_employee_in_category(employee_id, time_off_category_id)
      .where('effective_at < ?', date)
      .where.not(id: id)
  end

  private

  def no_balances_without_valid_policy
    time_off_after = first_time_off_after_effective_at
    return unless time_off_after.present? && time_off_after.employee_time_off_policy.id.eql?(id) &&
        effective_at > time_off_after.start_time &&
        !previous_policy_for(time_off_after.start_time).present?

    errors.add(
      :effective_at, 'Can \'t change if there are time offs after and there is no previous policy'
    )
  end

  def first_time_off_after_effective_at
    date = effective_at != effective_at_was ? effective_at_was : effective_at
    employee
      .time_offs
      .in_category(time_off_category_id)
      .where('end_time >= ?', date)
      .order(:start_time)
      .first
  end

  def balances_without_valid_policy_present?
    time_off_after = first_time_off_after_effective_at
    return unless time_off_after.present? && time_off_after.employee_time_off_policy.id.eql?(id) &&
        !previous_policy_for(effective_at_was).present?
    errors.add(
      :effective_at, 'Can \'t remove if there are time offs after and there is no previous policy'
    )
    errors.blank?
  end

  def verify_not_change_of_policy_type_in_category
    return if self.time_off_policy.reset
    firts_etop =
      employee
      .employee_time_off_policies
      .where(time_off_category_id: time_off_policy.time_off_category_id)
      .order(:effective_at)
      .first
    return unless
      firts_etop && firts_etop.time_off_policy.policy_type != time_off_policy.policy_type
    errors.add(
      :policy_type,
      'The employee has an existing policy of different type in the category'
    )
  end

  def add_category_id
    self.time_off_category_id = time_off_policy.time_off_category_id
  end
end
