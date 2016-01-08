class TimeOffPolicy < ActiveRecord::Base
  belongs_to :time_off_category
  has_many :employee_balances, class_name: 'Employee::Balance'

  validates :start_time, :end_time, :type, :time_off_category, presence: true
  validates :type, inclusion: { in: %w(counter balance) }
  validates :amount, numericality: { greater_than_or_equal_to: 0 }
  validate :end_time_after_start_time

  private

  def end_time_after_start_time
    return unless start_time && end_time
    errors.add(:end_time, 'Must be after start time') if start_time > end_time
  end
end
