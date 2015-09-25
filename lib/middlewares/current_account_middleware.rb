class CurrentAccountMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    @request = ActionDispatch::Request.new(env)

    set_current_account

    @app.call(env)
  end

  private

  def access_token
    @access_token ||= Doorkeeper.authenticate(@request)
  end

  def set_current_account
    if access_token.nil?
      Account.current = nil
    else
      Account.current = Account.joins(:users)
        .where(account_users: {id: access_token.resource_owner_id})
        .first
    end
  end
end
