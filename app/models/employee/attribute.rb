class Employee::Attribute < ActiveRecord::Base
  self.primary_key = 'id'

  belongs_to :employee, inverse_of: :employee_attributes
  belongs_to :attribute_definition,
    ->(attr) { readonly },
    class_name: 'Employee::AttributeDefinition'
  belongs_to :event,
    class_name: 'Employee::Event',
    foreign_key: 'employee_event_id'
  has_one :account, through: :employee

  private

  def readonly?
    true
  end
end
