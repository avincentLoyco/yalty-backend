class Employee < ActiveRecord::Base
  attr_readonly :uuid

  belongs_to :account, inverse_of: :employees
  has_many :employee_attribute_versions, class_name: 'Employee::AttributeVersion', inverse_of: :employee
end
