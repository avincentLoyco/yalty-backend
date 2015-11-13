class CurrentUserMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    @request = ActionDispatch::Request.new(env)

    set_current_account_user
    check_token(env)
  end

  def access_token
    RequestStore.fetch(:access_token) do
      Doorkeeper.authenticate(@request)
    end
  end

  def set_current_account_user
    if access_token.blank?
      Account::User.current = nil
    else
      Account::User.current = Account::User.where(id: access_token.resource_owner_id).first
    end
  end

  def check_token(env)
    if Account::User.current.nil? && env["HTTP_AUTHORIZATION"].present?
      [401, {"Content-Type" => "application/json"}, ['{"error": "User not authorized"}']]
    else
      @app.call(env)
    end
  end
end
