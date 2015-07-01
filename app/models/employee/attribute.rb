class Employee::Attribute < ActiveRecord::Base
  belongs_to :employee, inverse_of: :employee_attributes, required: true
  belongs_to :attribute_definition,
    ->(attr) { readonly },
    class_name: 'Employee::AttributeDefinition',
    required: true
  has_one :account, through: :employee

  validates :attribute_definition_id,
    uniqueness: { allow_nil: true, scope: [:employee] }

  serialize :data, AttributeSerializer

  after_initialize :set_attribute_definition

  def attribute_type
    attribute_definition.try(:attribute_type)
  end

  def name
    attribute_definition.try(:name)
  end

  def name=(value)
    @name ||= value

    set_attribute_definition

    @name
  end

  private

  def set_attribute_definition
    return if attribute_definition.present?

    if account.nil?
      self.attribute_definition = nil
    else
      self.attribute_definition = account.employee_attribute_definitions
        .where(name: @name)
        .readonly
        .first
    end
    data.attribute_type = attribute_type
  end
end
