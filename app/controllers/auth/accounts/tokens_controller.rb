class Auth::Accounts::TokensController < Doorkeeper::TokensController
  include AbstractController::Callbacks

  before_action :setup_params
  after_action :destroy_token, only: [:create]

  private

  def setup_params
    request.parameters.merge!(
      grant_type: "authorization_code",
      scope: ENV["YALTY_OAUTH_SCOPES"],
      redirect_uri: ENV["YALTY_OAUTH_REDIRECT_URI"],
      client_id: ENV["YALTY_OAUTH_ID"],
      client_secret: ENV["YALTY_OAUTH_SECRET"]
    )
  end

  def destroy_token
    strategy.grant.try(:destroy)
  end
end
