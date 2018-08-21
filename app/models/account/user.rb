class Account::User < ActiveRecord::Base
  include ActsAsIntercomData
  include UserIntercomData
  include StripeHelpers

  has_secure_password
  has_many :notifications

  validates :email, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :email, uniqueness: { scope: :account_id, case_sensitive: false }
  validates :email, exclusion: { in: [ENV["YALTY_ACCESS_EMAIL"]] }, if: ->() { !role.eql?("yalty") }
  validates :password, length: { in: 8..74 }, if: ->() { !password.nil? }
  validates :reset_password_token, uniqueness: true, allow_nil: true
  validates :role,
    presence: true,
    inclusion: { in: %w(user yalty account_administrator account_owner) }
  validates :locale, inclusion: { in: I18n.available_locales.map(&:to_s) }, allow_nil: true
  validates :employee, presence: true, unless: :empty_employee_allowed
  validate :validate_role_update, if: :role_changed?, on: :update
  validate :validate_yalty_role, if: -> { role.eql?("yalty") }

  belongs_to :account, inverse_of: :users, required: true
  belongs_to :referrer, primary_key: :email, foreign_key: :email
  has_one :employee, inverse_of: :user, foreign_key: :account_user_id

  before_validation :generate_password, unless: :password_digest?, on: :create
  after_create :create_referrer
  before_destroy :check_if_last_owner
  after_update :update_stripe_customer_email,
    if: -> { stripe_enabled? && (email_changed? || role_changed?) }
  after_destroy :update_stripe_customer_email,
    if: -> { stripe_enabled? && role_was.eql?("account_owner") }

  skip_callback :save, :after, :create_or_update_on_intercom, if: -> { role.eql?("yalty") }

  def self.current=(user)
    RequestStore.write(:current_account_user, user)
  end

  def self.current
    RequestStore.read(:current_account_user)
  end

  def access_token
    app = Doorkeeper::Application.where(uid: ENV["YALTY_OAUTH_ID"]).first!

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
    role.in?(%w(account_owner account_administrator yalty))
  end

  def default_locale
    locale || account&.default_locale
  end

  def inactive?
    employee_required? && (employee.nil? || !employee.hired_at?(Date.today))
  end

  private

  def create_referrer
    return if Referrer.where(email: email).exists?
    Referrer.create(email: email)
  end

  def update_stripe_customer_email
    return unless role_change&.include?("account_owner") || email_changed? || destroyed?
    Payments::UpdateStripeCustomerDescription.perform_later(account)
  end

  def validate_role_update
    if role_changed? && role_was.eql?("yalty")
      errors.add(:role, "yalty role cannot be changed to #{role}")
    elsif role_changed? && role_was.eql?("account_owner") &&
        !account.users.where.not(id: id).where(role: "account_owner").exists?
      errors.add(:role, "last account owner cannot change role")
    else
      return true
    end
    false
  end

  def validate_yalty_role
    if persisted? && email_changed?
      errors.add(:email, "is not allowed to be changed for yalty role")
    elsif persisted? && password_digest_changed?
      errors.add(:password, "is not allowed to be changed for yalty role")
    elsif employee.present?
      errors.add(:employee, "is not allowed to be set for yalty role")
    elsif account.users.where.not(id: id).where(role: "yalty").exists?
      errors.add(:role, "is allowed only once per account")
    elsif !email.eql?(ENV["YALTY_ACCESS_EMAIL"])
      errors.add(:email, "is restricted to #{ENV["YALTY_ACCESS_EMAIL"]} for yalty role")
    else
      return true
    end
    false
  end

  def check_if_last_owner
    return true unless role.eql?("account_owner") &&
        !account.users.where.not(id: id).where(role: "account_owner").exists?

    errors.add(:role, "last account owner cannot be deleted")
    false
  end

  def single_owner?
    role.eql?("account_owner") && account.users.where(role: "account_owner").count == 1
  end

  def empty_employee_allowed
    role.eql?("yalty") ||
      changed.eql?(%w(reset_password_token)) ||
      role.eql?("account_owner") && (
        account.nil? || account.recently_created? || changed.eql?(%w(password_digest))
      )
  end

  def employee_required?
    !(empty_employee_allowed || single_owner?)
  end
end
