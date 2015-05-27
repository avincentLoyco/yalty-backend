class Auth::AccountsController < Doorkeeper::ApplicationController
  protect_from_forgery with: :null_session

  def create
    ActiveRecord::Base.transaction do
      account = Account.create!(account_params)
      @current_resource_owner = account.users.create!(user_params)
    end

    auth = authorization.authorize

    respond_to do |format|
      format.json { render json: { code: auth.auth.token.token, redirect_uri: redirect_uri_with_subdomain(auth.redirect_uri) }, status: 201 }
      format.any  { redirect_to redirect_uri_with_subdomain(auth.redirect_uri) }
    end
  end

  private

  def redirect_uri_with_subdomain(redirect_uri)
    uri = URI(redirect_uri)
    uri.host.prepend("#{current_resource_owner.account.subdomain}.")
    uri.to_s
  end

  def pre_auth
    @pre_auth ||= Doorkeeper::OAuth::PreAuthorization.new(
      Doorkeeper.configuration,
      client,
      {
        response_type: 'code',
        redirect_uri: client.redirect_uri,
        scope: client.scopes.to_s
      }
    )
  end

  def client
    @client ||= Doorkeeper::OAuth::Client.find(ENV['YALTY_OAUTH_ID'])
  end

  def current_resource_owner
    @current_resource_owner
  end

  def authorization
    @authorization ||= strategy.request
  end

  def strategy
    @strategy ||= server.authorization_request pre_auth.response_type
  end

  def account_params
    params.require(:account).permit(:company_name)
  end

  def user_params
    params.require(:user).permit(:email, :password)
  end

end
