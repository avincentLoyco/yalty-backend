class Employee::Event < ActiveRecord::Base
  EVENT_TYPES = %w(
    default hired change moving_out contact_details_personal
    contact_details_professional contact_details_emergency
    work_permit bank_account job_details wedding divorce partnership
    spouse_professional_situation spouse_death child_birth child_death
    child_studies
  )

  belongs_to :employee, inverse_of: :events, required: true
  has_one :account, through: :employee
  has_many :employee_attribute_versions,
    inverse_of: :event,
    foreign_key: 'employee_event_id',
    class_name: 'Employee::AttributeVersion'

  validates :effective_at, presence: true
  validates :event_type,
    presence: true,
    inclusion: { in: EVENT_TYPES, allow_nil: true }
end
