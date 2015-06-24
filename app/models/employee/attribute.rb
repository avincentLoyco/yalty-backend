class Employee::Attribute < ActiveRecord::Base
  include AttributeSerializer

  belongs_to :employee, inverse_of: :employee_attributes, required: true
  has_one :account, through: :employee

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
end
