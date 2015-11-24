module DoorkeeperAuthorization
  def client
    @client ||= Doorkeeper::OAuth::Client.find(ENV['YALTY_OAUTH_ID'])
  end

  def authorization
    @authorization ||= strategy.request.authorize
  end

  def strategy
    @strategy ||= server.authorization_request(pre_auth.response_type)
  end

  def pre_auth
    @pre_auth ||= Doorkeeper::OAuth::PreAuthorization.new(
      Doorkeeper.configuration,
      client,
      response_type: 'code',
      redirect_uri: client.redirect_uri,
      scope: client.scopes.to_s
    )
  end
end
