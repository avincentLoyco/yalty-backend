class Employee::Attribute < ActiveRecord::Base
  belongs_to :employee, inverse_of: :employee_attributes
end
