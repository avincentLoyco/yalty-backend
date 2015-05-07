class Account < ActiveRecord::Base
  validates :subdomain, presence: true,
                        uniqueness: { case_sensitive: false },
                        format: { with: /\A[0-9a-z][0-9a-z\-]+[0-9a-z]\z/, allow_blank: true }
  validates :company_name, presence: true

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
                       .gsub(/\s/, '-')
                       .gsub(/(\A[\-]+)|([^0-9A-Za-z\-])|([\-]+\z)/, '')
                       .downcase

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
