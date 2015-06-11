class Employee < ActiveRecord::Base
  attr_readonly :uuid

  belongs_to :account, inverse_of: :employees
  has_many :employee_attributes, class_name: 'Employee::Attribute', inverse_of: :employee
end
