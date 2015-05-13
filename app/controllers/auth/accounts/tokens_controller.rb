class Auth::Accounts::TokensController < Doorkeeper::ApplicationMetalController
  def create
    request.parameters.merge!(authorize_params)
    response = authorize_response

    self.headers.merge!  response.headers
    self.response_body = response.body.to_json
    self.status        = response.status

    strategy.grant.destroy
  rescue Errors::DoorkeeperError => e
    handle_token_exception e
  end

  private

  def authorize_params
    {
      grant_type: 'authorization_code',
      scope: ENV['YALTY_OAUTH_SCOPES'],
      redirect_uri: ENV['YALTY_OAUTH_REDIRECT_URI'],
      client_id: ENV['YALTY_OAUTH_ID'],
      client_secret: ENV['YALTY_OAUTH_SECRET']
    }
  end

  def strategy
    @strategy ||= server.token_request params[:grant_type]
  end

  def authorize_response
    @authorize_response ||= strategy.authorize
  end
end
