class Account < ActiveRecord::Base
  SUPPORTED_TIMEZONES = ActiveSupport::TimeZone.all.map { |tz| tz.tzinfo.name } +
    ['Europe/Zurich']

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

  before_validation :generate_subdomain, on: :create
  after_create :update_default_attribute_definitions!

  def self.current=(account)
    RequestStore.write(:current_account, account)
  end

  def self.current
    RequestStore.read(:current_account)
  end

  DEFAULT_ATTRIBUTE_DEFINITIONS = [
    { name: 'firstname', type: Attribute::String.attribute_type },
    { name: 'lastname',  type: Attribute::String.attribute_type }
  ].freeze

  # Add defaults attribute definiitons
  #
  # Create all required Employee::AttributeDefinition for
  # the account
  def update_default_attribute_definitions!
    DEFAULT_ATTRIBUTE_DEFINITIONS.each do |attr|
      definition = employee_attribute_definitions.where(name: attr[:name]).first

      if definition.nil?
        definition = employee_attribute_definitions.build(
          name: attr[:name],
          attribute_type: attr[:type],
          system: true
        )
      end

      definition.save
    end
  end

  private

  # Generate a subdomain from company name
  #
  # Use activesupport transliatera to transform non ascii characters
  # and remove all other special characters except dash
  def generate_subdomain
    return unless new_record?

    if subdomain.blank? && company_name.present?
      self.subdomain = ActiveSupport::Inflector.transliterate(company_name)
                       .strip
                       .downcase
                       .gsub(/\s/, '-')
                       .gsub(/(\A[\-]+)|([^a-z\d-])|([\-]+\z)/, '')
                       .squeeze('-')

      ensure_subdomain_is_unique
    end
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