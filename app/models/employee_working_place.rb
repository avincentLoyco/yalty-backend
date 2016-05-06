class EmployeeWorkingPlace < ActiveRecord::Base
  belongs_to :employee
  belongs_to :working_place

  validates :employee_id, :working_place_id, :effective_at, presence: true
  validates :working_place_id, uniqueness: { scope: [:employee_id, :effective_at] }
end
