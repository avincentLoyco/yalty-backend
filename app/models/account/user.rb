class Account::User < ActiveRecord::Base
  has_secure_password

  validates :email, presence: true
  validates :password, length: { in: 8..74 }, if: ->() { !password.nil? }

  belongs_to :account, inverse_of: :users, required: true

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
end
