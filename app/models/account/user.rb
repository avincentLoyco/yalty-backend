class Account::User < ActiveRecord::Base
  include ActsAsIntercomData
  include UserIntercomData
  include StripeHelpers

  has_secure_password

  validates :email, presence: true
  validates :email, format: { with: /\b[A-Z0-9._%a-z\-]+@(?:[A-Z0-9a-z\-]+\.)+[A-Za-z]{2,4}\z/ }
  validates :email, uniqueness: { scope: :account_id, case_sensitive: false }
  validates :password, length: { in: 8..74 }, if: ->() { !password.nil? }
  validates :reset_password_token, uniqueness: true, allow_nil: true
  validates :role, presence: true, inclusion: { in: %w(user account_administrator account_owner) }
  validates :locale, inclusion: { in: I18n.available_locales.map(&:to_s) }, allow_nil: true
  validate :validate_role_update, if: :role_changed?, on: :update

  belongs_to :account, inverse_of: :users, required: true
  belongs_to :referrer, primary_key: :email, foreign_key: :email
  has_one :employee, foreign_key: :account_user_id

  before_validation :generate_password, on: :create
  after_create :create_referrer
  before_destroy :check_if_last_owner
  after_update :update_stripe_customer_email,
    if: -> { stripe_enabled? && (email_changed? || role_changed?) }
  after_destroy :update_stripe_customer_email,
    if: -> { stripe_enabled? && role_was.eql?('account_owner') }

  def self.current=(user)
    RequestStore.write(:current_account_user, user)
  end

  def self.current
    RequestStore.read(:current_account_user)
  end

  def access_token
    app = Doorkeeper::Application.where(uid: ENV['YALTY_OAUTH_ID']).first!

    Doorkeeper::AccessToken.find_or_create_for(
      app,
      id,
      app.scopes,
      Doorkeeper.configuration.access_token_expires_in,
      true
    ).token
  end

  def generate_reset_password_token
    self.reset_password_token = SecureRandom.urlsafe_base64(16)
  end

  def generate_password
    self.password ||= SecureRandom.urlsafe_base64(12)
  end

  def owner_or_administrator?
    %w(account_owner account_administrator).include?(role)
  end

  private

  def create_referrer
    return if Referrer.where(email: email).exists?
    Referrer.create(email: email)
  end

  def update_stripe_customer_email
    return unless role_change&.include?('account_owner') || email_changed? || destroyed?
    Payments::UpdateStripeCustomerDescription.perform_later(account)
  end

  def validate_role_update
    return unless role_change && role_change.first.eql?('account_owner') &&
        !account.users.where.not(id: id).where(role: 'account_owner').exists?

    errors.add(:role, 'last account owner cannot change role')
  end

  def check_if_last_owner
    return unless role.eql?('account_owner') &&
        !account.users.where.not(id: id).where(role: 'account_owner').exists?

    errors.add(:role, 'last account owner cannot be deleted')
    errors.blank?
  end
end
