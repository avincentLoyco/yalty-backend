class ServiceRequestMailer < ApplicationMailer
  helper_method :account, :user, :services, :options_for_service, :service_booking_url_for,
    :address_attributes

  def quote_request(account, user, services)
    @account = account
    @user = user
    @services = services

    I18n.with_locale(@user.default_locale) do
      mail to: @user.email,
           bcc: [ENV["YALTY_SERVICE_EMAIL"], ENV["CJODRY_EMAIL"]]
    end
  end

  def book_request(account, user, services)
    @account = account
    @user = user
    @services = services

    I18n.with_locale(@user.default_locale) do
      mail to: @user.email,
           bcc: ENV["YALTY_SERVICE_EMAIL"]
    end
  end

  private

  attr_reader :account, :user, :services

  def options_for_service(service)
    service.reject { |k| %I(toggle meta).include?(k.to_sym) }
  end

  def service_booking_url_for(account)
    subdomain_url_for(account) + "/account/payment/yalty-services"
  end

  def address_attributes
    %i(
      company_name address_1 address_2 postalcode city region country
    ).map { |attr| account.company_information.public_send(attr) }.compact
  end
end
