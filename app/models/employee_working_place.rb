class EmployeeWorkingPlace < ActiveRecord::Base
  include ValidateEffectiveAtBetweenHiredAndContractEndDates

  attr_accessor :effective_till

  belongs_to :employee
  belongs_to :working_place

  validates :employee, :working_place, :effective_at, presence: true
  validates :effective_at, uniqueness: { scope: [:employee_id, :working_place_id] }

  scope :with_reset, -> { joins(:working_place).where(working_places: { reset: true }) }
  scope :not_reset, -> { joins(:working_place).where(working_places: { reset: false }) }
  scope :assigned_since, ->(date) { where("effective_at >= ?", date) }

  alias related_resource working_place
end
