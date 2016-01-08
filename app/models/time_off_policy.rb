class TimeOffPolicy < ActiveRecord::Base
  belongs_to :time_off_category
  has_many :employee_balances, class_name: 'Employee::Balance'

  validates :start_time, :end_time, :type, :time_off_category, presence: true
  validates :type, inclusion: { in: %w(counter balance) }

  def balance?
    type == 'balance'
  end
end
