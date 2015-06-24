class Employee::AttributeDefinition < ActiveRecord::Base
  validates :name, presence: true, uniqueness: { scope: :account_id, case_sensitive: false }
  validates :label, presence: true
  validates :system, inclusion: { in: [true, false] }
  validates :attribute_type,
    presence: true,
    inclusion: { in: ->(model) { Employee::Attribute.attribute_types } }

  belongs_to :account, inverse_of: :employee_attributes, required: true
end
