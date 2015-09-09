class Employee::AttributeVersion < ActiveRecord::Base
  belongs_to :employee, inverse_of: :employee_attribute_versions, required: true
  belongs_to :attribute_definition,
    ->(attr) { readonly },
    class_name: 'Employee::AttributeDefinition',
    required: true
  belongs_to :event,
    class_name: 'Employee::Event',
    foreign_key: 'employee_event_id',
    inverse_of: :employee_attribute_versions,
    required: true
  has_one :account, through: :employee

  validates :attribute_definition_id,
    uniqueness: { allow_nil: true, scope: [:employee] }

  serialize :data, AttributeSerializer

  after_initialize :set_attribute_definition

  def attribute_type
    attribute_definition.try(:attribute_type)
  end

  def attribute_name
    attribute_definition.try(:name)
  end

  def attribute_name=(value)
    @attribute_name ||= value

    set_attribute_definition

    @attribute_name
  end

  def effective_at
    event.try(:effective_at)
  end

  private

  def set_attribute_definition
    if !attribute_definition.present?
      if account.nil?
        self.attribute_definition = nil
      else
        self.attribute_definition = account.employee_attribute_definitions
          .where(name: @attribute_name)
          .readonly
          .first
      end
    end

    data.attribute_type = attribute_type
  end
end
