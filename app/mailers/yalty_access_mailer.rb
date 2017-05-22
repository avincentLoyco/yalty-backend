class YaltyAccessMailer < ApplicationMailer
  attr_reader :account, :user
  helper_method :account, :user, :subdomain_url_for

  def access_enable(account)
    @account = account
    @user = Account::User.where(account: account, role: 'yalty').first

    mail to: user.email
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
