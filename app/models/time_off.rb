class TimeOff < ActiveRecord::Base
  belongs_to :employee
  belongs_to :time_off_category
  has_one :employee_balance, class_name: 'Employee::Balance'

  validates :employee_id, :time_off_category_id, :start_time, :end_time, presence: true
  validate :end_time_after_start_time
  validate :time_off_policy_presence, if: 'employee.present?'
  validates :employee_balance, presence: true, on: :update
  validate :start_time_after_employee_creation, if: :employee

  def balance
    - CalculateTimeOffBalance.new(self).call
  end

  private

  def end_time_after_start_time
    return unless start_time && end_time
    errors.add(:end_time, 'Must be after start time') if start_time > end_time
  end

  def time_off_policy_presence
    return if employee.active_policy_in_category_at_date(time_off_category_id).try(:time_off_policy)
    errors.add(:employee, 'Time off policy in category required')
  end

  def start_time_after_employee_creation
    return unless start_time < employee.created_at
    errors.add(:start_time, 'Can not be added before employee creation')
  end
end
