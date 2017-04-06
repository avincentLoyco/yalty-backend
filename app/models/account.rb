class Account < ActiveRecord::Base
  include ActsAsIntercomData
  include AccountIntercomData
  include StripeHelpers

  serialize :invoice_company_info, Payments::CompanyInformation

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
  validate :timezone_must_exist, if: -> { timezone.present? }
  validates :default_locale, inclusion: { in: I18n.available_locales.map(&:to_s) }
  validate :referrer_must_exist, if: :referred_by, on: :create

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
  has_many :employee_working_places, through: :employees
  has_many :employee_time_off_policies, through: :employees
  has_many :employee_presence_policies, through: :employees
  has_many :invoices
  belongs_to :referrer, primary_key: :token, foreign_key: :referred_by

  before_validation :generate_subdomain, on: :create
  after_create :update_default_attribute_definitions!
  after_create :update_default_time_off_categories!
  after_create :create_reset_presence_policy_and_working_place!
  after_create :create_stripe_customer_with_subscription, if: :stripe_enabled?
  after_update :update_stripe_customer_description,
    if: -> { stripe_enabled? && (subdomain_changed? || company_name_changed?) }

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
    child: { inclusion: true },
    profile_picture: { presence: { allow_nil: true } },
    salary_slip: { presence: { allow_nil: true } },
    contract: { presence: { allow_nil: true } },
    salary_certificate: { presence: { allow_nil: true } },
    id_card: { presence: { allow_nil: true } },
    work_permit: { presence: { allow_nil: true } },
    avs_card: { presence: { allow_nil: true } }
  }.with_indifferent_access

  MULTIPLE_ATTRIBUTES = %w(child).freeze

  ATTRIBUTES_WITH_LONG_TOKEN = %w(profile_picture).freeze

  DEFAULT_ATTRIBUTES = {
    Attribute::String.attribute_type => %w(
      firstname lastname avs_number gender nationality language personal_email
      personal_phone professional_email professional_mobile emergency_lastname
      emergency_firstname emergency_phone permit_type tax_source_code bank_name
      account_owner_name iban clearing_number job_title contract_type department
      cost_center manager spouse_working_region professional_phone personal_mobile
      spouse_is_working bank_account_number tax_canton
    ),
    Attribute::Date.attribute_type => %w(birthdate permit_expiry),
    Attribute::Number.attribute_type => %w(occupation_rate monthly_payments tax_rate),
    Attribute::Currency.attribute_type => %w(annual_salary hourly_salary representation_fees),
    Attribute::Address.attribute_type => %w(address),
    Attribute::Child.attribute_type => %w(child),
    Attribute::Person.attribute_type => %w(spouse),
    Attribute::File.attribute_type => %w(
      profile_picture salary_slip contract salary_certificate id_card work_permit avs_card
    )
  }.freeze

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
      if definition.present? && attr[:validation].present? &&
          definition.validation != attr[:validation]
        definition.validation = attr[:validation]
      end

      if definition.nil?
        definition = employee_attribute_definitions.build(
          name: attr[:name],
          attribute_type: attr[:type],
          system: true,
          multiple: MULTIPLE_ATTRIBUTES.include?(attr[:name]),
          validation: attr[:validation],
          long_token_allowed: ATTRIBUTES_WITH_LONG_TOKEN.include?(attr[:name])
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
    DEFAULT_ATTRIBUTE_DEFINITIONS
  end

  def total_amount_of_data
    employee_attribute_versions
      .where("data -> 'attribute_type' = 'File'")
      .sum("(data -> 'size')::float / (1024.0 * 1024.0)").round(2)
  end

  def number_of_files
    employee_attribute_versions.where("data -> 'attribute_type' = 'File'").count
  end

  def employee_files_ratio
    return 0 if employees.count.zero?
    (number_of_files.to_f / employees.count.to_f).round(2)
  end

  def create_reset_presence_policy_and_working_place!
    presence_policies.create!(name: 'Reset policy', reset: true)
    working_places.create!(name: 'Reset working place', reset: true)
  end

  def stripe_description
    "#{company_name} (#{subdomain})"
  end

  def stripe_email
    users.where(role: 'account_owner').reorder('created_at ASC').limit(1).pluck(:email).first
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

  def referrer_must_exist
    return if Referrer.where(token: referred_by).exists?
    errors.add(:referred_by, 'must belong to existing referrer')
  end

  def timezone_must_exist
    return if ActiveSupport::TimeZone[timezone].present?
    errors.add(:timezone, 'must be a valid time zone')
  end

  def create_stripe_customer_with_subscription
    Payments::CreateOrUpdateCustomerWithSubscription.perform_now(self)
  end

  def update_stripe_customer_description
    return if subdomain_was.nil? || company_name_was.nil?
    Payments::UpdateStripeCustomerDescription.perform_later(self)
  end
end
