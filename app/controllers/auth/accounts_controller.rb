class Auth::AccountsController < Doorkeeper::ApplicationController
  protect_from_forgery with: :null_session
  include DoorkeeperAuthorization

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

  def list
    users = Account::User.includes(:account).where(email: user_email)

    if users.present?
      accounts_subdomains = users.map { |user| user.account.subdomain }
      UserMailer.accounts_list(user_email, accounts_subdomains).deliver_later
    end

    head 204
  end

  private

  attr_reader :current_resource_owner

  def account_registration_key
    Account::RegistrationKey.unused.find_by!(token: registration_key_params[:token])
  end

  def account_params
    params.require(:account).permit(:company_name)
  end

  def user_params
    params.require(:user).permit(:email, :password)
  end

  def registration_key_params
    params.require(:registration_key).permit(:token)
  end

  def user_email
    params.require(:email)
  end

  def redirect_uri_with_subdomain(redirect_uri)
    uri = URI(redirect_uri)
    uri.host.prepend("#{current_resource_owner.account.subdomain}.")
    uri.to_s
  end

  def create_account
    ActiveRecord::Base.transaction do
      registration_key = account_registration_key
      account = Account.create!(account_params)
      registration_key.update!(account: account)
      @current_resource_owner = account.users.create!(user_params)
    end
    send_user_credentials(user_params[:password])
  end

  def send_user_credentials(password)
    user_id = current_resource_owner.id
    subdomain = @current_resource_owner.account.subdomain
    UserMailer.credentials(
      user_id,
      password,
      subdomain + '.' + ENV['YALTY_BASE_URL']
    ).deliver_later
  end
end
