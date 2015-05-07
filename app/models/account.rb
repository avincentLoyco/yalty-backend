class Account < ActiveRecord::Base
  validates :subdomain, presence: true,
                        uniqueness: { case_sensitive: false },
                        format: { with: /\A[0-9a-z][0-9a-z\-]+[0-9a-z]\z/, allow_blank: true }
  validates :company_name, presence: true

  before_validation :generate_subdomain, on: :create

  private

  def generate_subdomain
    if subdomain.blank? && company_name.present?
      self.subdomain = ActiveSupport::Inflector.transliterate(company_name)
                       .strip
                       .gsub(/\s/, '-')
                       .gsub(/(\A[\-]+)|([^0-9A-Za-z\-])|([\-]+\z)/, '')
                       .downcase
    end
  end
end
