class EmployeeWorkingPlace < ActiveRecord::Base
  attr_accessor :effective_till

  belongs_to :employee
  belongs_to :working_place

  validates :employee, :working_place, :effective_at, presence: true
  validates :effective_at, uniqueness: { scope: [:employee_id, :working_place_id] }
  validate :effective_at_newer_than_first_event, if: [:employee, :effective_at]
  validate :first_employee_working_place_at_start_date, if: [:employee, :effective_at]

  scope :by_employee, -> (employee_id) { where(employee_id: employee_id) }

  private

  def first_employee_working_place_at_start_date
    first_working_place = employee.first_employee_working_place
    hired_date = employee.hired_date

    return if hired_date.blank? || (first_working_place.try(:id) != id ||
        hired_date == effective_at) || (first_working_place.blank? && effective_at == hired_date)
    errors.add(:effective_at, 'First EmployeeWorkingPlace must have effective at hired date')
  end

  def effective_at_newer_than_first_event
    not_editable = employee.first_employee_working_place
    return if !not_editable || id == not_editable.id || not_editable.effective_at < effective_at
    errors.add(:effective_at, 'Must be after first employee working place effective_at')
  end
end
