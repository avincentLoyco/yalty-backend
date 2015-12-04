class Employee::Event < ActiveRecord::Base
  EVENT_ATTRIBUTES = {
    default: %w(),
    change: %w(),
    hired: %w(firstname lastname avs_number birthdate gender nationality language),
    moving_out: %w(address),
    contact_details_personal: %w(personal_email personal_phone personal_mobile),
    contact_details_professional: %w(professional_email professional_mobile professional_phone),
    contact_details_emergency: %w(emergency_lastname emergency_firstname emergency_phone),
    work_permit: %w(permit_type permit_expiry tax_source_code),
    bank_account: %w(bank_name account_owner_name iban clearing_number),
    job_details: %w(job_title start_date exit_date contract_type occupation_rate department
                    cost_center manager annual_salary hourly_salary representation_fees
                    monthly_payments),
    wedding: %w(lastname civil_status civil_status_date tax_source_code account_owner_name spouse),
    divorce: %w(lastname civil_status civil_status_date tax_source_code account_owner_name spouse),
    partnership: %w(lastname civil_status civil_status_date tax_source_code account_owner_name
                    spouse),
    spouse_professional_situation: %w(spouse_is_working spouse_working_region),
    spouse_death: %w(civil_status civil_status_date tax_source_code),
    child_birth: %w(tax_source_code child),
    child_death: %w(tax_source_code),
    child_studies: %w(child_is_student)
  }.with_indifferent_access

  belongs_to :employee, inverse_of: :events, required: true
  has_one :account, through: :employee
  has_many :employee_attribute_versions,
    inverse_of: :event,
    foreign_key: 'employee_event_id',
    class_name: 'Employee::AttributeVersion'

  validates :effective_at, presence: true
  validates :event_type,
    presence: true,
    inclusion: { in: proc { Employee::Event.event_types }, allow_nil: true }
  validate :attributes_presence, if: Proc.new { |event| event.event_attributes.size > 0 }

  def self.event_types
    Employee::Event::EVENT_ATTRIBUTES.keys.map(&:to_s)
  end

  def event_attributes
    Employee::Event::EVENT_ATTRIBUTES[event_type]
  end

  def attributes_presence
    required = event_attributes & Employee::AttributeDefinition.required(Account.current)
    defined = attributes_defined_in_event + already_defined_attributes
    missing = required - defined
    return if missing.empty?
    errors.add :employee_attribute_versions, "missing params: #{ missing.join(', ') }"
  end

  def attributes_defined_in_event
    self.employee_attribute_versions.map { |version| version.attribute_definition.name }
  end

  def already_defined_attributes
    self.employee.employee_attribute_versions.map do |version|
      version.attribute_definition.name
    end
  end
end
