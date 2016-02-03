class Auth::UsersController < ApplicationController
  include UserPasswordRules

  before_action :authenticate_account!, only: :reset_password

  def reset_password
    verified_params(gate_rules) do |attributes|
      user = resource_from_email(attributes[:email])
      user.generate_reset_password_token
      user.save!
      send_reset_password_token(user)
      render_no_content
    end
  end

  def new_password
    verified_params(gate_rules) do |attributes|
      resource = resource_from_token(attributes.delete(:reset_password_token))
      resource.update!(attributes)
      render_no_content
    end
  end

  private

  def resource_from_email(email)
    @resource ||= Account.current.users.find_by!(email: email)
  end

  def resource_from_token(token)
    @resource ||= Account.current.users.find_by!(reset_password_token: token)
  end

  def url_with_subdomain_and_token(user)
    str = Account.current.subdomain + '.' + ENV['YALTY_APP_DOMAIN']
    str + '/password?reset_password_token=' + user.reset_password_token
  end

  def send_reset_password_token(user)
    UserMailer.reset_password(
      user.id,
      url_with_subdomain_and_token(user)
    ).deliver_later
  end

  def authenticate_account!
    return unless Account.current.blank?
    render json:
      ::Api::V1::ErrorsRepresenter.new(nil, message: 'Account unauthorized').complete, status: 401
  end
end
