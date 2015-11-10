class Employee::AttributeVersion < ActiveRecord::Base
  include ActsAsAttribute

  belongs_to :employee, inverse_of: :employee_attribute_versions, required: true
  belongs_to :event,
    class_name: 'Employee::Event',
    foreign_key: 'employee_event_id',
    inverse_of: :employee_attribute_versions,
    required: true
  has_one :account, through: :employee

  validates :attribute_definition_id,
    uniqueness: { allow_nil: true, scope: [:employee, :event] },
    if: '!multiple?'

  validates :order, presence: true, if: 'multiple?'

  def effective_at
    event.try(:effective_at)
  end
end
