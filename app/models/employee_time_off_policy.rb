require 'employee_policy_period'

class EmployeeTimeOffPolicy < ActiveRecord::Base
  include ActsAsIntercomTrigger
  include ValidateEffectiveAtBeforeHired

  attr_accessor :effective_till

  belongs_to :employee
  belongs_to :time_off_policy
  belongs_to :time_off_category

  validates :employee_id, :time_off_policy_id, :effective_at, presence: true
  validates :effective_at, uniqueness: { scope: [:employee_id, :time_off_category_id] }
  validate :no_balances_after_effective_at, if: [:time_off_policy, :effective_at]
  validate :verify_not_change_of_policy_type_in_category, if: [:employee, :time_off_policy]
  before_save :add_category_id

  before_destroy :verify_if_no_balances_after_effective_at

  scope :not_assigned_at, -> (date) { where(['effective_at > ?', date]) }
  scope :assigned_at, -> (date) { where(['effective_at <= ?', date]) }
  scope :by_employee_in_category, lambda { |employee_id, category_id|
    joins(:time_off_policy)
      .where(time_off_policies: { time_off_category_id: category_id }, employee_id: employee_id)
      .order(effective_at: :desc)
  }

  def policy_assignation_balance(effective_at = self.effective_at)
    employee.employee_balances.where(
      time_off_category_id: time_off_policy.time_off_category.id,
      time_off_id: nil
    ).where('effective_at::date = ?', effective_at).first
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

  private

  def verify_if_no_balances_after_effective_at
    no_balances_after_effective_at.blank?
  end

  def verify_not_change_of_policy_type_in_category
    firts_etop =
      employee
      .employee_time_off_policies
      .where(time_off_category_id: time_off_policy.time_off_category_id)
      .first
    return unless
      firts_etop && firts_etop.time_off_policy.policy_type != time_off_policy.policy_type
    errors.add(
      :policy_type,
      'The employee has an existing policy of different type in the category'
    )
  end

  def no_balances_after_effective_at
    assignation_balance_id = policy_assignation_balance(effective_at_was).try(:id)
    older = effective_at_was && effective_at_was < effective_at ? effective_at_was : effective_at
    balances_after_effective_at =
      Employee::Balance
      .employee_balances(employee_id, time_off_policy.time_off_category_id)
      .where('effective_at >= ?', older)
      .where.not(id: assignation_balance_id)

    return unless balances_after_effective_at.present?
    errors.add(:time_off_category, 'Employee balance after effective at already exists')
  end

  def add_category_id
    self.time_off_category_id = time_off_policy.time_off_category_id
  end
end
