class EmployeeWorkingPlace < ActiveRecord::Base
  attr_accessor :effective_till

  belongs_to :employee
  belongs_to :working_place

  validates :employee, :working_place, :effective_at, presence: true
  validates :effective_at, uniqueness: { scope: [:employee_id, :working_place_id] }
  validate :effective_at_newer_than_first_event, if: [:employee, :effective_at]
  validate :effective_at_cant_be_before_start_date, if: [:employee, :effective_at]

  scope :by_employee, -> (employee_id) { where(employee_id: employee_id) }

  private

  def effective_at_cant_be_before_start_date
    return unless employee.hired_date.present? && effective_at < employee.hired_date
    errors.add(:effective_at, 'can\'t be set before employee hired_date')
  end

  def effective_at_newer_than_first_event
    not_editable = employee.first_employee_working_place
    return if !not_editable || id == not_editable.id || not_editable.effective_at < effective_at
    errors.add(:effective_at, 'Must be after first employee working place effective_at')
  end
end
