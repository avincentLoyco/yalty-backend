class Auth::AccountsController < ApplicationController
  protect_from_forgery with: :null_session
  include DoorkeeperAuthorization
  include AccountSchemas

  def create
    verified_dry_params(dry_validation_schema) do |attributes|
      account, user = build_account_and_user(attributes)

      verify_if_user_is_not_refering_himself!(user.email, account)

      ActiveRecord::Base.transaction do
        save!(account, user)
        user.convert_intercom_leads
      end

      send_account_creation_confirmation
      render_response
    end
  end

  def list
    dry_validation_schema = Dry::Validation.Form do
      required(:email).filled(:str?)
    end

    verified_dry_params(dry_validation_schema) do |attributes|
      users = Account::User.includes(:account).where(email: attributes[:email])

      account_ids = if users.present?
                      users.map { |user| user.account.id }
                    else
                      []
                    end

      UserMailer.accounts_list(attributes[:email], account_ids).deliver_later
      render_no_content
    end
  end

  private

  attr_reader :current_resource_owner

  def build_account_and_user(params)
    account = Account.new(params[:account])
    user = account.users.new(params[:user].merge(role: "account_owner"))
    [account, user]
  end

  def save!(account, user)
    if account.valid? && user.valid?
      account.save!
      @current_resource_owner = user
    else
      messages = account.errors.messages
                        .merge(user.errors.messages)

      raise InvalidResourcesError.new(account, messages)
    end
  end

  def render_response
    respond_to do |format|
      format.json do
        render status: 201, json: {
          code: authorization_token,
          redirect_uri: authorization_uri,
        }
      end
      format.any do
        redirect_to authorization_uri
      end
    end
  end

  def send_account_creation_confirmation
    UserMailer.account_creation_confirmation(
      current_resource_owner.id
    ).deliver_later
  end

  def verify_if_user_is_not_refering_himself!(email, account)
    referred_by = account.referred_by
    return unless referred_by.present? && Referrer.find_by(email: email).try(:token) == referred_by
    raise InvalidResourcesError.new(account, ["can't use own referral token"])
  end
end
