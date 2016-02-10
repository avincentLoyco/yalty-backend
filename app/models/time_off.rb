class TimeOff < ActiveRecord::Base
  belongs_to :employee
  belongs_to :time_off_category
  has_one :employee_balance, class_name: 'Employee::Balance'

  validates :employee_id, :time_off_category_id, :start_time, :end_time, presence: true
  validate :end_time_after_start_time
  validate :time_off_policy_presence, if: 'employee.present?'
  validates :employee_balance, presence: true, on: :update

  def balance
    - (end_time - start_time) / 60
  end

  private

  def end_time_after_start_time
    return unless start_time && end_time
    errors.add(:end_time, 'Must be after start time') if start_time > end_time
  end

  def time_off_policy_presence
    return unless employee.active_policy_in_category(time_off_category_id).blank?
    errors.add(:employee, 'Time off policy in category required')
  end
end
