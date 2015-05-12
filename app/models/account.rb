class Account < ActiveRecord::Base
  validates :subdomain, presence: true,
                        uniqueness: { case_sensitive: false },
                        length: { maximum: 63 },
                        format: { with: /\A[a-z\d]+(?:[-][a-z\d]+)*\z/, allow_blank: true },
                        exclusion: { in: Yalty.reserved_subdomains }
  validates :company_name, presence: true

  has_many :users, class_name: 'Account::User', inverse_of: :account

  before_validation :generate_subdomain, on: :create

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
