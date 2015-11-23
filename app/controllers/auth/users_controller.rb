class Auth::UsersController < ApplicationController
  include UserPasswordRules

  before_action :authenticate_account!, only: :reset_password

  def reset_password
    verified_params(gate_rules) do |attributes|
      user = resource_from_email(attributes[:email])
      user.generate_reset_password_token
      if user.save
        send_reset_password_token(user)
        render_no_content
      else
        resource_invalid_error(resource)
      end
    end
  end

  def new_password
    verified_params(gate_rules) do |attributes|
      resource = resource_from_token(attributes.delete(:reset_password_token))
      if resource.update(attributes)
        render_no_content
      else
        resource_invalid_error(resource)
      end
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
    Account.current.subdomain + '.' + ENV['YALTY_BASE_URL'] + '/password/reset_password_token='\
    + user.reset_password_token
  end

  def send_reset_password_token(user)
    UserMailer.reset_password(
      user.id,
      url_with_subdomain_and_token(user)
    ).deliver_later
  end

  def authenticate_account!
    if Account.current.blank?
      render json:
        ::Api::V1::ErrorsRepresenter.new(nil, message: 'Account unauthorized').complete, status: 401
    end
  end
end
