class Employee::Attribute < ActiveRecord::Base
  include AttributeSerializer

  belongs_to :employee, inverse_of: :employee_attributes, required: true
  belongs_to :attribute_definition,
    ->(attr) { readonly },
    class_name: 'Employee::AttributeDefinition',
    required: true
  has_one :account, through: :employee

  validates :attribute_definition_id, uniqueness: { allow_nil: true }

  def self.inherited(klass)
    super

    attribute_types << klass.attribute_type
  end

  def self.attribute_types
    @attribute_types ||= []
  end

  def self.attribute_type
    name.gsub(/^.+::/, '')
  end

  def attribute_type
    self.class.attribute_type
  end

  def name
    attribute_definition.try(:name)
  end

  def name=(value)
    if account.nil?
      self.attribute_definition = nil
    else
      self.attribute_definition = account.employee_attributes.where(
        name: value,
        attribute_type: attribute_type
      ).readonly.first
    end

    name
  end
end
