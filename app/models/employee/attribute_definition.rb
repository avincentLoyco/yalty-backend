class Employee::AttributeDefinition < ActiveRecord::Base
  belongs_to :account,
    inverse_of: :employee_attribute_definitions,
    required: true

  validates :name,
    presence: true,
    uniqueness: { scope: :account_id, case_sensitive: false }
  validates :system, inclusion: { in: [true, false] }
  validates :attribute_type,
    presence: true,
    inclusion: { in: ->(_) { Attribute::Base.attribute_types } }
end
