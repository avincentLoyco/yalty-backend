class CurrentUserMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    @request = ActionDispatch::Request.new(env)

    find_current_account_user
    check_token(env)
  end

  def access_token
    RequestStore.fetch(:access_token) do
      Doorkeeper.authenticate(@request)
    end
  end

  def find_current_account_user
    Account::User.current =
      access_token.blank? ? nil : Account::User.where(id: access_token.resource_owner_id).first
  end

  def check_token(env)
    if Account::User.current.nil? && bearer_auth?(env)
      [401, { "Content-Type" => "application/json" }, ['{"error": "User not authorized"}']]
    else
      @app.call(env)
    end
  end

  def bearer_auth?(env)
    env["HTTP_AUTHORIZATION"].present? && env["HTTP_AUTHORIZATION"].match?(/^Bearer/)
  end
end
