class Auth::AccountsController < Doorkeeper::ApplicationController
  protect_from_forgery with: :null_session

  before_action :create_account, only: [:create]

  def create
    respond_to do |format|
      format.json do
        render status: 201, json: {
          code: authorization.auth.token.token,
          redirect_uri: redirect_uri_with_subdomain(authorization.redirect_uri)
        }
      end
      format.any do
        redirect_to redirect_uri_with_subdomain(authorization.redirect_uri)
      end
    end
  end

  private

  attr_reader :current_resource_owner

  def client
    @client ||= Doorkeeper::OAuth::Client.find(ENV['YALTY_OAUTH_ID'])
  end

  def authorization
    @authorization ||= strategy.request.authorize
  end

  def strategy
    @strategy ||= server.authorization_request(pre_auth.response_type)
  end

  def account_registration_key
    Account::RegistrationKey.unused.find_by!(token: registration_key_params[:token])
  end

  def account_params
    params.require(:account).permit(:company_name, registration_key: [:token])
  end

  def user_params
    params.require(:user).permit(:email, :password)
  end

  def registration_key_params
    params.require(:registration_key).permit(:token)
  end

  def redirect_uri_with_subdomain(redirect_uri)
    uri = URI(redirect_uri)
    uri.host.prepend("#{current_resource_owner.account.subdomain}.")
    uri.to_s
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

  def create_account
    ActiveRecord::Base.transaction do
      registration_key = account_registration_key
      account = Account.create!(account_params)
      registration_key.update!(account: account)
      @current_resource_owner = account.users.create!(user_params)
    end
  end
end
