class Employee::Event < ActiveRecord::Base
  EVENT_ATTRIBUTES = {
    default: %w(),
    change: %w(),
    hired: %w(firstname lastname birthdate gender personal_email professional_email
              occupation_rate),
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
    performance_review: %w(performance_review),
    salary_certificate: %w(salary_certificate),
    salary_paid: %w(salary_slip),
    spouse_professional_situation: %w(spouse_is_working spouse_working_region),
    spouse_death: %w(spouse),
    child_birth: %w(child),
    child_death: %w(child),
    child_adoption: %w(child),
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
  validate :contract_end_and_hire_in_valid_order, if: [:employee, :event_type, :effective_at]

  scope :contract_ends, -> { where(event_type: 'contract_end') }
  scope :hired, -> { where(event_type: 'hired') }
  scope :contract_types, -> { where(event_type: %w(contract_end hired)) }
  scope :all_except, ->(id) { where.not(id: id) }

  before_destroy :check_if_event_deletable

  def self.event_types
    Employee::Event::EVENT_ATTRIBUTES.keys.map(&:to_s)
  end

  def event_attributes
    Employee::Event::EVENT_ATTRIBUTES[event_type]
  end

  def attributes_presence
    # TODO: Refactor required attributes - excluding files is temporary
    required = event_attributes & Employee::AttributeDefinition.not_file.required
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

  def can_destroy_event?
    hired_without_events_and_join_tables_after? ||
      !%w(hired contract_end).include?(event_type) || contract_end_without_rehired_after?
  end

  private

  def balances_before_hired_date
    return unless event_type.eql?('hired')
    hired_event =
      employee
      .events
      .hired
      .where('effective_at <= ?', effective_at)
      .all_except(id).order(:effective_at).last

    return unless hired_event.blank? && balances_before_effective_at?
    errors.add(:base, 'There can\'t be balances before hired date')
  end

  def balances_before_effective_at?
    employee.employee_balances.where('effective_at < ?', effective_at).present?
  end

  def next_events
    employee.events.all_except(id).where('effective_at > ?', effective_at).order(:effective_at)
  end

  def contract_end_and_hire_in_valid_order
    return unless event_type.in?(%w(contract_end hired))
    work_events =
      employee.events.contract_types.all_except(id).where('effective_at <= ?', effective_at)
    current_type = work_events.select { |event| event[:event_type].eql?(event_type) }
    other_type = work_events - current_type
    at_date = other_type.any? { |event| event[:effective_at].eql?(effective_at) }

    return if ((event_type.eql?('contract_end') && (current_type.size + 1).eql?(other_type.size)) ||
        hired_events_in_valid_order?(current_type.size, other_type.size, at_date)) &&
        (!next_events.contract_types.first&.event_type.eql?(event_type) || at_date)

    errors.add(
      :event_type,
      "Employee can not have two #{event_type} in a row and contract end must have hired event"
    )
  end

  def hired_events_in_valid_order?(current_type, other_type, at_date)
    event_type.eql?('hired') && ((!at_date && current_type.eql?(other_type)) ||
      (at_date && (current_type + 1).eql?(other_type)))
  end

  def check_if_event_deletable
    can_destroy_event? || errors.add(:base, 'Event cannot be destroyed')
    errors.empty?
  end

  def hired_without_events_and_join_tables_after?
    return unless event_type.eql?('hired')

    employee.events.where('effective_at >= ?', effective_at).all_except(id).empty? &&
      Employee::RESOURCE_JOIN_TABLES.map do |join_table|
        employee.send(join_table).not_reset.assigned_since(effective_at).empty?
      end.uniq.eql?([true])
  end

  def contract_end_without_rehired_after?
    event_type.eql?('contract_end') &&
      !employee
        .events
        .where('effective_at > ?', effective_at)
        .order(:effective_at).first&.event_type.eql?('hired')
  end
end
