class ApplicationMailer < ActionMailer::Base
  default from: ENV['YALTY_APP_EMAIL']

  helper_method :subdomain_url_for

  private

  def subdomain_url_for(account)
    url = ''
    url << (Rails.configuration.force_ssl ? 'https://' : 'http://')
    url << "#{account.subdomain}.#{ENV['YALTY_APP_DOMAIN']}"
    url << ":#{ENV['EMBER_PORT']}" if Rails.env == 'e2e-testing'
    url
  end
end
