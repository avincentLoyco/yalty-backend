class EmployeeWorkingPlace < ActiveRecord::Base
  include ValidateEffectiveAtBeforeHired
  include ValidateNoBalancesAfterJoinTableEffectiveAt

  attr_accessor :effective_till

  belongs_to :employee
  belongs_to :working_place

  validates :employee, :working_place, :effective_at, presence: true
  validates :effective_at, uniqueness: { scope: [:employee_id, :working_place_id] }
end
