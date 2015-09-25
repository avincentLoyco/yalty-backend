class Employee::Attribute < ActiveRecord::Base
  include ActsAsAttribute

  self.primary_key = 'id'

  belongs_to :employee, inverse_of: :employee_attributes
  belongs_to :event,
    class_name: 'Employee::Event',
    foreign_key: 'employee_event_id'
  has_one :account, through: :employee

  private

  def readonly?
    true
  end
end
