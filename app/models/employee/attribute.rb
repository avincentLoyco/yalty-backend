class Employee::Attribute < ActiveRecord::Base
  include ActsAsAttribute

  self.primary_key = 'id'

  belongs_to :employee, inverse_of: :employee_attributes
  belongs_to :event,
    class_name: 'Employee::Event',
    foreign_key: 'employee_event_id'
  belongs_to :employee_attribute_definition
  has_one :account, through: :employee

  scope :for_other_employees, -> { where(attribute_name: PUBLIC_ATTRIBUTES_FOR_OTHERS) }

  private

  def readonly?
    true
  end
end
