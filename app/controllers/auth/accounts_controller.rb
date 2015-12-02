class Auth::AccountsController < ApplicationController
  protect_from_forgery with: :null_session
  include DoorkeeperAuthorization
  include AccountRules

  def create
    verified_params(gate_rules) do |attributes|
      account, user = build_account_and_user(attributes)

      ActiveRecord::Base.transaction do
        save!(account, user)
      end

      send_user_credentials(attributes[:user][:password])
      render_response
    end
  end

  def list
    verified_params(get_rules) do |attributes|
      users = Account::User.includes(:account).where(email: attributes[:email])

      if users.present?
        accounts_subdomains = users.map { |user| user.account.subdomain }
        UserMailer.accounts_list(attributes[:email], accounts_subdomains).deliver_later
      end

      render_no_content
    end
  end

  private

  attr_reader :current_resource_owner

  def build_account_and_user(attributes)
    account = Account.new(attributes[:account])
    user = account.users.new(attributes[:user])
    account.registration_key = account_registration_key(attributes[:registration_key])
    [account, user]
  end

  def save!(account, user)
    if account.valid? && user.valid? && account.registration_key.valid?
      account.save!
      @current_resource_owner = user
    else
      messages = account.errors.messages
        .merge(user.errors.messages)
        .merge(account.try(:registration_key).errors.messages)

      fail InvalidResourcesError.new(account, messages)
    end
  end

  def render_response
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

  def send_user_credentials(password)
    user_id = current_resource_owner.id
    subdomain = current_resource_owner.account.subdomain
    UserMailer.credentials(
      user_id,
      password,
      subdomain + '.' + ENV['YALTY_BASE_URL']
    ).deliver_later
  end

  def account_registration_key(token)
    Account::RegistrationKey.unused.find_by!(token)
  end
end
