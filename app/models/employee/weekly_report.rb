class Employee::WeeklyReport < ActiveRecord::Base
  include AASM

  belongs_to :employee

  validates :employee, :date_from, :date_to, :worked, :planned, :bank_holidays, :absences,
    :difference, :status, :year, presence: true

  enum status: { to_complete: 0, to_approve: 1, approved: 2, to_correct: 3, auto_approved: 4 }

  aasm :status, enum: true, no_direct_assignment: true, skip_validation_on_save: true do
    state :to_complete, initial: true
    state :to_approve, :approved, :to_correct

    event :submit do
      transitions from: [:to_complete, :to_correct], to: :to_approve
    end

    event :approve do
      transitions from: :to_approve, to: :approved
    end

    event :reject do
      transitions from: [:to_approve, :approved], to: :to_correct
    end
  end

  scope :year,     ->(year)        { where(year: year) }
  scope :employee, ->(employee_id) { where(employee_id: employee_id) }
end
