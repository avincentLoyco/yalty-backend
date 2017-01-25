class Employee::Event < ActiveRecord::Base
  EVENT_ATTRIBUTES = {
    default: %w(),
    change: %w(),
    hired: %w(firstname lastname birthdate gender personal_email professional_email),
    moving: %w(address),
    contact_details_personal: %w(firstname lastname personal_email personal_phone personal_mobile
                                 address id_card),
    contact_details_professional: %w(professional_email professional_mobile professional_phone),
    contact_details_emergency: %w(emergency_lastname emergency_firstname emergency_phone),
    identity: %w(firstname lastname avs_number birthdate gender nationality language permit_type
                 permit_expiry id_card work_permit profile_picture avs_card),
    tax_at_source: %w(tax_source_code tax_canton),
    bank_account: %w(bank_name account_owner_name iban clearing_number bank_account_number),
    work_contract: %w(job_title contract_type occupation_rate department cost_center manager
                      annual_salary hourly_salary representation_fees monthly_payments avs_number
                      tax_rate salary_slip salary_certificate contract),
    marriage: %w(firstname lastname id_card spouse),
    divorce: %w(firstname lastname id_card spouse),
    partnership: %w(firstname lastname id_card spouse),
    partnership_dissolution: %w(firstname lastname id_card spouse),
    spouse_professional_situation: %w(spouse_is_working spouse_working_region),
    spouse_death: %w(spouse),
    child_birth: %w(child),
    child_death: %w(child),
    partner_death: %w(spouse),
    child_studies: %w(child),
    contract_end: %w()
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
  validate :attributes_presence, if: [:event_attributes, :employee]
  validate :balances_before_hired_date, if: :employee, on: :update
  validate :no_two_contract_end_dates_or_hired_events_in_row, if: [:employee, :event_type]

  def self.event_types
    Employee::Event::EVENT_ATTRIBUTES.keys.map(&:to_s)
  end

  def event_attributes
    Employee::Event::EVENT_ATTRIBUTES[event_type]
  end

  def attributes_presence
    required = event_attributes & Employee::AttributeDefinition.required
    defined = attributes_defined_in_event + already_defined_attributes
    missing = required - defined
    return if missing.empty?
    errors.add :employee_attribute_versions, "missing params: #{missing.join(', ')}"
  end

  def attributes_defined_in_event
    employee_attribute_versions.map { |version| version.attribute_definition.try(:name) }
  end

  def already_defined_attributes
    employee.employee_attribute_versions.map do |version|
      version.attribute_definition.name
    end
  end

  def previous_event
    employee
      .events.where.not(id: id).where('effective_at < ?', effective_at).order(:effective_at).last
  end

  def next_event
    employee
      .events.where.not(id: id).where('effective_at > ?', effective_at).order(:effective_at).first
  end

  private

  def balances_before_hired_date
    return unless event_type == 'hired' && balances_before_effective_at?
    errors.add(:base, 'There can\'t be balances before hired date')
  end

  def balances_before_effective_at?
    employee.employee_balances.where('effective_at < ?', effective_at).present?
  end

  def only_one_hired_event_presence
    return unless event_type == 'hired'
    employee_hired_events = employee.events.where(event_type: 'hired')
    return unless employee_hired_events.present? && employee_hired_events.pluck(:id).exclude?(id)
    errors.add(:event_type, 'Employee can have only one hired event')
  end

  def no_two_contract_end_dates_or_hired_events_in_row
    return unless contract_end_and_hire_not_alternately?
    errors.add(:event_type, "Employee can't have two #{event_type} events in a row")
  end

  def contract_end_and_hire_not_alternately?
    (event_type.eql?('hired') || event_type.eql?('contract_end')) &&
      (previous_event&.event_type.eql?(event_type) || next_event&.event_type.eql?(event_type))
  end
end
