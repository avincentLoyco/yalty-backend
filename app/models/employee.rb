class Employee < ActiveRecord::Base
  attr_readonly :uuid

  belongs_to :account, inverse_of: :employees
  has_many :employee_attribute_versions, class_name: 'Employee::AttributeVersion', inverse_of: :employee
  has_many :employee_attributes, class_name: 'Employee::Attribute', inverse_of: :employee
  has_many :events, class_name: 'Employee::Event', inverse_of: :employee
end
