class Employee::Attribute < ActiveRecord::Base
  include AttributeSerializer

  belongs_to :employee, inverse_of: :employee_attributes
  has_one :account, through: :employee

  def self.inherited(klass)
    super

    name = klass.name.gsub(/^.+::/, '')
    attribute_types << name
  end

  def self.attribute_types
    @attribute_types ||= []
  end

end
