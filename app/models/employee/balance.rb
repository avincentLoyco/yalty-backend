class Employee::Balance < ActiveRecord::Base
  belongs_to :employee
  belongs_to :time_off_category
  belongs_to :time_off
  belongs_to :time_off_policy

  validates :employee, :time_off_category, :balance, :amount, :time_off_policy, presence: true
  validates :amount, numericality: true

  before_validation :calculate_and_set_balance, if: :attributes_present?

  def last_in_category?
    self.id == employee.last_balance_in_category(time_off_category_id).id
  end

  def later_balances_ids
    time_off_policy.employee_balances.where("created_at >= ? AND time_off_category_id = ?",
      self.created_at, self.time_off_category_id).pluck(:id)
  end

  def calculate_and_set_balance
    previous = previous_balance
    self.balance = previous && previous.id != id ? previous.balance + amount : amount
  end

  private

  def previous_balance
    Employee::Balance.where('created_at < ?', self.created_at)
      .order(created_at: :asc).last
  end

  def attributes_present?
    employee.present? && time_off_category.present? && amount.present?
  end
end
