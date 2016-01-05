class Account::User < ActiveRecord::Base
  include ActsAsIntercomData

  has_secure_password

  validates :email, presence: true
  validates :email, format: { with: /\b[A-Z0-9._%a-z\-]+@(?:[A-Z0-9a-z\-]+\.)+[A-Za-z]{2,4}\z/ }
  validates :password, length: { in: 8..74 }, if: ->() { !password.nil? }
  validates :reset_password_token, uniqueness: true, allow_nil: true

  belongs_to :account, inverse_of: :users, required: true
  has_one :employee, foreign_key: :account_user_id

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

  def intercom_type
    :users
  end

  def intercom_attributes
    %w(id created_at email)
  end

  def intercom_data
    {
      user_id: id,
      email: email,
      signed_up_at: created_at,
      companies: [{
        company_id: account.id
      }]
    }
  end
end
