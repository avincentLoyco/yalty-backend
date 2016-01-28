class Employee::Balance < ActiveRecord::Base
  belongs_to :employee
  belongs_to :time_off_category
  belongs_to :time_off
  belongs_to :time_off_policy

  validates :employee, :time_off_category, :balance, :amount, :time_off_policy, presence: true
  validate :time_off_policy_date, if: 'time_off_policy.present?'
  validates :effective_at, uniqueness: { scope: [:time_off_policy, :employee] }

  before_validation :calculate_and_set_balance, if: :attributes_present?
  before_validation :set_effective_at, if: 'effective_at.blank?'

  def last_in_category?
    id == employee.last_balance_in_category(time_off_category_id).id
  end

  def next_balance
    time_off_policy.employee_balances.where('effective_at > ? AND employee_id = ?',
      now_or_effective_at, self.employee_id).order(effective_at: :asc).first.try(:id)
  end

  def current_or_next_period?
    time_off_policy.current_period.cover?(effective_at) ||
      time_off_policy.next_period.cover?(effective_at)
  end

  def later_balances_ids
    return nil unless time_off_policy
    current_or_next_period? || last_removal_smaller_than_amount? ?
      all_later_ids : check_removal_and_return_ids
  end

  def last_removal_smaller_than_amount?
    removals_since_effective_at.blank? || amount > last_removal.amount
  end

  def calculate_and_set_balance
    previous = previous_balance
    self.balance = previous && previous.id != id ? previous.balance + amount : amount
  end

  private

  def check_removal_and_return_ids
    ids = removals_since_effective_at.each do |removal|
      if removal.amount >= amount
        return self.class.where('effective_at > ? AND effective_at < ? AND employee_id = ?',
          self.effective_at, removal.effectve_at, employee_id).pluck(:id)
      end
    end
    ids.present? ? ids : all_later_ids
  end

  def removals_since_effective_at
    self.class.where('policy_credit_removal = true AND effective_at > ? AND employee_id = ?',
      self.effective_at, employee_id).order(effective_at: :asc)
  end

  def all_later_ids
    time_off_policy.employee_balances.where("effective_at >= ? AND employee_id = ?",
      self.effective_at, self.employee_id).pluck(:id)
  end

  def set_effective_at
    self.effective_at = Time.now
  end

  def previous_balance
    time_off_policy.employee_balances.where('effective_at < ? AND employee_id = ?',
      now_or_effective_at, self.employee_id).order(effective_at: :asc).last
  end

  def now_or_effective_at
    effective_at || Time.now
  end

  def attributes_present?
    employee.present? && time_off_category.present? && amount.present?
  end

  def time_off_policy_date
    return if current_or_next_period? || time_off_policy.previous_period.cover?(effective_at)
    errors.add(:effective_at, 'Must belong to current, next or previous policy.')
  end
end
