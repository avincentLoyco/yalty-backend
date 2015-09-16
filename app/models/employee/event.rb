class Employee::Event < ActiveRecord::Base
  belongs_to :employee, inverse_of: :events, required: true
  has_one :account, through: :employee
  has_many :employee_attribute_versions,
    inverse_of: :event,
    foreign_key: 'employee_event_id',
    class_name: 'Employee::AttributeVersion'

  validates :effective_at, presence: true
  validates :event_type,
    presence: true,
    inclusion: { in: %w(default hired), allow_nil: true }
end
