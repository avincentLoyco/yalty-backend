module DoorkeeperAuthorization
  include Doorkeeper::Helpers::Controller

  def authorization_uri
    uri = URI(authorization.redirect_uri)
    uri.host.prepend("#{current_resource_owner.account.subdomain}.")
    uri.to_s
  end

  def authorization_token
    authorization.auth.token.token
  end

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
