class Auth::UsersController < ApplicationController
  include UserPasswordSchemas

  before_action :authenticate_account!, only: :reset_password

  def reset_password
    verified_dry_params(dry_validation_schema) do |attributes|
      user = resource_from_email(attributes[:email])
      user.generate_reset_password_token
      user.save!
      send_reset_password_token(user)
      render_no_content
    end
  end

  def new_password
    verified_dry_params(dry_validation_schema) do |attributes|
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

  def send_reset_password_token(user)
    UserMailer.reset_password(
      user.id
    ).deliver_later
  end

  def authenticate_account!
    return unless Account.current.blank?
    render json:
      ::Api::V1::ErrorsRepresenter.new(nil, error: ['Account unauthorized']).complete, status: 401
  end
end
