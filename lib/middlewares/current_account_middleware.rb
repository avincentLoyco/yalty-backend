class CurrentAccountMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    @request = ActionDispatch::Request.new(env)

    set_current_account_user
    set_current_account

    @app.call(env)
  end

  private

  def access_token
    RequestStore.fetch(:access_token) do
      Doorkeeper.authenticate(@request)
    end
  end

  def set_current_account_user
    if access_token.nil?
      Account::User.current = nil
    else
      Account::User.current = Account::User.where(id: access_token.resource_owner_id).first
    end
  end

  def set_current_account
    if Account::User.current.nil?
      Account.current = nil
    else
      Account.current = Account.joins(:users)
        .where(account_users: { id: Account::User.current.id })
        .first
    end
  end
end
