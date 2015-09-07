class Employee::Event < ActiveRecord::Base
  belongs_to :employee, inverse_of: :events, required: true
  has_one :account, through: :employee
  has_many :employee_attribute_versions,
    inverse_of: :events,
    class_name: 'Employee:AttributeVersion'

  validates :effective_at, presence: true
end
