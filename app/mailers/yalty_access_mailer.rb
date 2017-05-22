class YaltyAccessMailer < ApplicationMailer
  attr_reader :account
  helper_method :account, :subdomain_url_for

  def access_enable(account)
    @account = account

    mail to: ENV['YALTY_ACCESS_EMAIL']
  end

  def access_disable(account)
    @account = account

    mail to: ENV['YALTY_ACCESS_EMAIL']
  end

  private

  def subdomain_url_for(account)
    url = ''
    url << (Rails.configuration.force_ssl ? 'https://' : 'http://')
    url << "#{account.subdomain}.#{ENV['YALTY_APP_DOMAIN']}"
    url << ":#{ENV['EMBER_PORT']}" if Rails.env == 'e2e-testing'
    url
  end
end
