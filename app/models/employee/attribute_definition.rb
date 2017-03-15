require 'attribute'

class Employee::AttributeDefinition < ActiveRecord::Base
  belongs_to :account,
    inverse_of: :employee_attribute_definitions,
    required: true

  has_many :employee_attributes,
    class_name: 'Employee::Attribute'

  validates :name,
    presence: true,
    uniqueness: { scope: :account_id, case_sensitive: false }
  validates :multiple, :system, :long_token_allowed, inclusion: { in: [true, false] }
  validates :attribute_type,
    presence: true,
    inclusion: { in: ->(_) { Attribute::Base.attribute_types } }

  scope :required, lambda {
    where("(validation -> 'presence' = 'true') AND (account_id = ?)", Account.current).pluck(:name)
  }
end
