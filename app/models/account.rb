class Account < ActiveRecord::Base
  include ActsAsIntercomData

  SUPPORTED_TIMEZONES = ActiveSupport::TimeZone.all
    .map { |tz| tz.tzinfo.name } + ['Europe/Zurich']

  validates :subdomain,
    presence: true,
    uniqueness: { case_sensitive: false },
    length: { maximum: 63 },
    format: {
      with: /\A[a-z\d]+(?:[-][a-z\d]+)*\z/,
      allow_blank: true
    },
    exclusion: { in: Yalty.reserved_subdomains }
  validates :company_name, presence: true
  validates :timezone,
    inclusion: { in: SUPPORTED_TIMEZONES },
    if: -> { timezone.present? }
  validates :default_locale, inclusion: { in: %w(de en fr) }

  # It is assigned to account holiday_policy as default
  belongs_to :holiday_policy, inverse_of: :assigned_account
  has_many :users,
    class_name: 'Account::User',
    inverse_of: :account
  has_many :employees, inverse_of: :account
  has_many :employee_attribute_definitions,
    class_name: 'Employee::AttributeDefinition',
    inverse_of: :account
  has_many :working_places, inverse_of: :account
  has_many :employee_events, through: :employees, source: :events
  has_many :employee_attribute_versions, through: :employees
  has_many :holiday_policies
  has_many :presence_policies
  has_many :presence_days, through: :presence_policies
  has_one :registration_key, class_name: 'Account::RegistrationKey'
  has_many :time_off_categories
  has_many :time_offs, through: :time_off_categories
  has_many :time_entries, through: :presence_days
  has_many :time_off_policies, through: :time_off_categories
  has_many :employee_balances, through: :employees

  before_validation :generate_subdomain, on: :create
  after_create :update_default_attribute_definitions!
  after_create :update_default_time_off_categories!

  def self.current=(account)
    RequestStore.write(:current_account, account)
  end

  def self.current
    RequestStore.read(:current_account)
  end

  ATTR_VALIDATIONS = {
    lastname: { presence: true },
    firstname: { presence: true },
    start_date: { presence: true },
    contract_type: { presence: true },
    occupation_rate: { presence: true }
  }.with_indifferent_access

  MULTIPLE_ATTRIBUTES = %w(child spouse)

  DEFAULT_ATTRIBUTES = {
    Attribute::String.attribute_type => %w(
      firstname lastname avs_number gender nationality language personal_email
      personal_phone professional_email professional_mobile emergency_lastname
      emergency_firstname emergency_phone permit_type tax_source_code bank_name
      account_owner_name iban clearing_number job_title contract_type department
      cost_center manager civil_status spouse_working_region
    ),
    Attribute::Date.attribute_type => %w(
      birthdate permit_expiry start_date exit_date civil_status_date
    ),
    Attribute::Number.attribute_type => %w(occupation_rate monthly_payments),
    Attribute::Currency.attribute_type => %w(
      annual_salary hourly_salary representation_fees
    ),
    Attribute::Address.attribute_type => %w(address),
    Attribute::Child.attribute_type => %w(child),
    Attribute::Person.attribute_type => %w(spouse)
  }

  DEFAULT_ATTRIBUTE_DEFINITIONS = Account::DEFAULT_ATTRIBUTES.map do |type, attributes|
    attributes.map do |name|
      { name: name, type: type, validation: ATTR_VALIDATIONS[name] }
    end
  end.flatten.freeze

  # Add defaults attribute definiitons
  #
  # Create all required Employee::AttributeDefinition for
  # the account
  def update_default_attribute_definitions!
    default_attribute_definition.each do |attr|
      definition = employee_attribute_definitions.where(name: attr[:name]).first

      if definition.nil?
        definition = employee_attribute_definitions.build(
          name: attr[:name],
          attribute_type: attr[:type],
          system: true,
          multiple: MULTIPLE_ATTRIBUTES.include?(attr[:name]),
          validation: attr[:validation]
        )
      end

      definition.save
    end
  end

  # Add defaults TimeOffCategories
  def update_default_time_off_categories!
    TimeOffCategory.update_default_account_categories(self)
  end

  def default_attribute_definition
    if Rails.env.test?
      DEFAULT_ATTRIBUTE_DEFINITIONS.first(2)
    else
      DEFAULT_ATTRIBUTE_DEFINITIONS
    end
  end

  def intercom_type
    :companies
  end

  def intercom_attributes
    %w(id created_at company_name subdomain)
  end

  def intercom_data
    {
      company_id: id,
      name: company_name,
      remote_created_at: created_at,
      custom_attributes: {
        subdomain: subdomain
      }
    }
  end

  private

  # Generate a subdomain from company name
  #
  # Use activesupport transliatera to transform non ascii characters
  # and remove all other special characters except dash
  def generate_subdomain
    return unless new_record?
    return unless subdomain.blank?
    return unless company_name.present?

    self.subdomain = ActiveSupport::Inflector.transliterate(company_name)
      .strip
      .downcase
      .gsub(/\s/, '-')
      .gsub(/(\A[\-]+)|([^a-z\d-])|([\-]+\z)/, '')
      .squeeze('-')

    ensure_subdomain_is_unique
  end

  # Ensure subdomain is unique
  #
  # Add a random suffix to subdomain composed by 4 chars after a dash
  def ensure_subdomain_is_unique
    suffix = ''

    loop do
      if Account.where(subdomain: subdomain + suffix).exists?
        suffix = '-' + String(SecureRandom.random_number(999) + 1)
      else
        self.subdomain = subdomain + suffix
        break
      end
    end
  end
end
