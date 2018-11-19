class Account < ActiveRecord::Base
  include ActsAsIntercomData
  include AccountIntercomData
  include StripeHelpers

  serialize :company_information, Payments::CompanyInformation
  serialize :available_modules, Payments::AvailableModules

  validates :subdomain,
    presence: true,
    uniqueness: { case_sensitive: false },
    length: { maximum: 63 },
    format: {
      with: /\A[a-z\d]+(?:[-][a-z\d]+)*\z/,
      allow_blank: true,
    },
    exclusion: { in: Yalty.reserved_subdomains }
  validates :company_name, presence: true
  validates :default_locale, inclusion: { in: I18n.available_locales.map(&:to_s) }
  validate :timezone_must_exist, if: -> { timezone.present? }
  validate :referrer_must_exist, if: :referred_by, on: :create

  with_options if: :any_active_presence_policies?, on: :update do
    validates :default_full_time_presence_policy_id, :standard_day_duration, presence: true
  end

  has_many :users, -> { where.not(role: "yalty") },
    class_name: "Account::User",
    inverse_of: :account
  has_many :employees, inverse_of: :account, dependent: :destroy
  has_many :employee_attribute_definitions,
    class_name: "Employee::AttributeDefinition",
    inverse_of: :account
  has_many :working_places, inverse_of: :account
  has_many :employee_events, through: :employees, source: :events
  has_many :employee_attribute_versions, through: :employees
  has_many :holiday_policies
  has_many :presence_policies
  belongs_to :default_full_time_presence_policy, class_name: "PresencePolicy"
  has_many :presence_days, through: :presence_policies
  has_one :registration_key, class_name: "Account::RegistrationKey"
  has_many :time_off_categories, dependent: :destroy
  has_many :time_offs, through: :time_off_categories
  has_many :time_entries, through: :presence_days
  has_many :time_off_policies, through: :time_off_categories
  has_many :employee_balances, through: :employees
  has_many :employee_working_places, through: :employees
  has_many :employee_time_off_policies, through: :employees
  has_many :employee_presence_policies, through: :employees
  has_many :invoices, dependent: :destroy
  has_many :company_events, dependent: :destroy
  belongs_to :referrer, primary_key: :token, foreign_key: :referred_by
  has_one :archive_file, as: :fileable, class_name: "GenericFile"
  has_many :managers, -> { joins(:employee) }, class_name: "Account::User"
  has_many :admins, -> { admins }, class_name: "Account::User"

  scope :with_yalty_access, lambda {
    joins("INNER JOIN account_users ON account_users.account_id = accounts.id")
      .where("account_users.role = 'yalty'")
  }

  before_validation :generate_subdomain, on: :create
  before_validation :set_recently_created, on: :create
  after_create :update_default_attribute_definitions!
  after_create :update_default_time_off_categories!
  after_create :create_reset_presence_policy_and_working_place!
  after_create :create_intercom_and_stripe_resources
  after_update :update_stripe_customer_description,
    if: -> { stripe_enabled? && (subdomain_changed? || company_name_changed?) }
  after_save :update_yalty_access

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
    spouse: { inclusion: true },
    profile_picture: { presence: { allow_nil: true } },
    salary_slip: { presence: { allow_nil: true } },
    contract: { presence: { allow_nil: true } },
    salary_certificate: { presence: { allow_nil: true } },
    id_card: { presence: { allow_nil: true } },
    work_permit: { presence: { allow_nil: true } },
    avs_card: { presence: { allow_nil: true } },
    performance_review: { presence: { allow_nil: true } },
    nationality: { country_code: true },
    tax_canton: { state_code: true },
    spouse_working_region: { state_code: true },
    occupation_rate: { range: [0, 1], presence: true },
    adjustment: { integer: true },
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
      spouse_is_working bank_account_number tax_canton comment title comment_communication
    ),
    Attribute::Date.attribute_type => %w(birthdate permit_expiry),
    Attribute::Number.attribute_type => %w(occupation_rate monthly_payments tax_rate adjustment),
    Attribute::Currency.attribute_type => %w(annual_salary hourly_salary representation_fees),
    Attribute::Address.attribute_type => %w(address),
    Attribute::Child.attribute_type => %w(child),
    Attribute::Person.attribute_type => %w(spouse),
    Attribute::File.attribute_type => %w(
      profile_picture salary_slip contract salary_certificate id_card work_permit avs_card
      performance_review
    ),
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

  def employee_files_ratio
    return 0 if employees.count.zero?
    (number_of_files.to_f / employees.count.to_f).round(2)
  end

  def number_of_files
    employee_attribute_versions.where("data -> 'attribute_type' = 'File'").count
  end

  def create_reset_presence_policy_and_working_place!
    presence_policies.create!(name: "Reset policy", reset: true)
    working_places.create!(name: "Reset working place", reset: true)
  end

  def stripe_description
    "#{company_name} (#{subdomain})"
  end

  def stripe_email
    users.where(role: "account_owner").reorder("created_at ASC").limit(1).pluck(:email).first
  end

  def yalty_access
    if @yalty_access.nil?
      Account::User.where(account_id: id, role: "yalty").exists?
    else
      @yalty_access
    end
  end

  def yalty_access=(value)
    value = (value == true)
    return value if value == yalty_access
    attribute_will_change!(:yalty_access)
    @yalty_access = value
  end

  def recently_created?
    new_record? || @recently_created
  end

  def vacation_category
    time_off_categories.find_by(name: "vacation")
  end

  def any_active_presence_policies?
    presence_policies.not_reset.active.any?
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
                                             .gsub(/\s/, "-")
                                             .gsub(/(\A[\-]+)|([^a-z\d-])|([\-]+\z)/, "")
                                             .squeeze("-")

    ensure_subdomain_is_unique
  end

  # Ensure subdomain is unique
  #
  # Add a random suffix to subdomain composed by 4 chars after a dash
  def ensure_subdomain_is_unique
    suffix = ""

    loop do
      if Account.where(subdomain: subdomain + suffix).exists?
        suffix = "-" + String(SecureRandom.random_number(999) + 1)
      else
        self.subdomain = subdomain + suffix
        break
      end
    end
  end

  def set_recently_created
    @recently_created = new_record?
  end

  def referrer_must_exist
    return if Referrer.where(token: referred_by).exists?
    errors.add(:referred_by, "must belong to existing referrer")
  end

  def timezone_must_exist
    return if ActiveSupport::TimeZone[timezone].present?
    errors.add(:timezone, "must be a valid time zone")
  end

  def create_intercom_and_stripe_resources
    SendDataToIntercom.perform_now(id, self.class.name)
    Payments::CreateOrUpdateCustomerWithSubscription.perform_now(self) if stripe_enabled?
  end

  def update_stripe_customer_description
    return if subdomain_was.nil? || company_name_was.nil?
    Payments::UpdateStripeCustomerDescription.perform_later(self)
  end

  def update_yalty_access
    return unless attribute_changed?(:yalty_access)

    if @yalty_access
      Account::User.find_or_create_by(
        account_id: id,
        email: ENV["YALTY_ACCESS_EMAIL"],
        password_digest: ENV["YALTY_ACCESS_PASSWORD_DIGEST"],
        role: "yalty"
      )
      YaltyAccessMailer.access_enable(self).deliver_later
    else
      Account::User.where(account_id: id, role: "yalty").destroy_all
      YaltyAccessMailer.access_disable(self).deliver_later
    end
  ensure
    @yalty_access = nil
  end
end
