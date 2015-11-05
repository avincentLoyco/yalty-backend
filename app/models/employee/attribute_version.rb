class Employee::AttributeVersion < ActiveRecord::Base
  include ActsAsAttribute

  belongs_to :employee, inverse_of: :employee_attribute_versions, required: true
  belongs_to :event,
    class_name: 'Employee::Event',
    foreign_key: 'employee_event_id',
    inverse_of: :employee_attribute_versions,
    required: true
  has_one :account, through: :employee

  validates :order,
    uniqueness: { scope: [:event, :attribute_definition] },
    presence: true,
    if: "attribute_definition.present? && attribute_definition.multiple?"

  def effective_at
    event.try(:effective_at)
  end
end
