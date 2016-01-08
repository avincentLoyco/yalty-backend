class Employee::Balance < ActiveRecord::Base
  belongs_to :employee
  belongs_to :time_off_category
  belongs_to :time_off
  belongs_to :time_off_policy

  validates :employee, :time_off_category, :balance, presence: true
  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }, if: :balance?
end
