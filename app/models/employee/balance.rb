class Employee::Balance < ActiveRecord::Base
  belongs_to :employee
  belongs_to :time_off_category
  belongs_to :time_off
  belongs_to :time_off_policy

  validates :employee, :time_off_category, :balance, :amount, :time_off_policy, presence: true
  validates :amount, numericality: true

  before_validation :calculate_and_set_balance, if: :attributes_present?

  def calculate_and_set_balance
    last_balance = employee.last_balance_in_category(time_off_category_id)
    self.balance = last_balance && last_balance.id != id ? last_balance.balance + amount : amount
  end

  private

  def attributes_present?
    employee.present? && time_off_category.present? && amount.present?
  end
end
