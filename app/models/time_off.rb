class TimeOff < ActiveRecord::Base
  belongs_to :employee
  belongs_to :time_off_category
  has_one :employee_balance, class_name: 'Employee::Balance'

  validates :employee_id, :time_off_category_id, :start_time, :end_time, presence: true
  validate :end_time_after_start_time
  validate :time_off_policy_presence, if: 'employee.present?'
  validates :employee_balance, presence: true, on: :update
  validate :start_time_after_employee_start_date, if: [:employee, :start_time, :end_time]
  validate :does_not_overlap_with_other_users_time_offs, if: [:employee, :time_off_category_id]

  scope :for_employee_in_period, lambda { |employee_id, start_date, end_date|
    where(employee_id: employee_id)
      .where(
        '((start_time BETWEEN ? AND ?) OR
        (end_time BETWEEN ? AND ?) OR
        (end_time > ? AND start_time < ?))',
        start_date, end_date, start_date, end_date, end_date, start_date
      )
      .order(:start_time)
  }

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

  def start_time_after_employee_start_date
    return unless start_time < employee.first_employee_event.effective_at
    errors.add(:start_time, 'Can not be added before employee start date')
  end

  def does_not_overlap_with_other_users_time_offs
    employee_time_offs_in_period =
      employee
      .time_offs
      .where(
        '(start_time >= ? AND start_time < ?) OR (end_time > ? AND end_time <= ?)',
        start_time, end_time, start_time, end_time
      )
    return if (employee_time_offs_in_period - [self]).blank?
    errors.add(:start_time, 'Time off in period already exist')
    errors.add(:end_time, 'Time off in period already exist')
  end
end
