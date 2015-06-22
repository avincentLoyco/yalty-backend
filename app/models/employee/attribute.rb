class Employee::Attribute < ActiveRecord::Base
  include AttributeSerializer

  belongs_to :employee, inverse_of: :employee_attributes
  has_one :account, through: :employee
end
