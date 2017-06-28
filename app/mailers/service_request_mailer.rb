class ServiceRequestMailer < ApplicationMailer
  helper_method :account, :user, :services, :options_for_service

  def quote_request(account, user, services)
    @account = account
    @user = user
    @services = services

    I18n.with_locale(@user.locale || @account.default_locale) do
      mail to: ENV['YALTY_SERVICE_EMAIL']
    end
  end

  def book_request(account, user, services)
    @account = account
    @user = user
    @services = services

    I18n.with_locale(@user.locale || @account.default_locale) do
      mail to: ENV['YALTY_SERVICE_EMAIL']
    end
  end

  private

  attr_reader :account, :user, :services

  def options_for_service(service)
    service.reject { |k| %I(toggle meta).include?(k.to_sym) }
  end
end
