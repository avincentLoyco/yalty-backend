class ExportMailer < ApplicationMailer
  helper_method :archive_url_for

  def archive_generation(account)
    @account = account

    I18n.with_locale(account.default_locale) do
      mail(to: recipients(@account),
           subject: default_i18n_subject(company_name: account.company_name))
    end
  end

  private

  def recipients(account)
    account.users.where(role: 'account_owner').pluck(:email)
  end

  def archive_url_for(account)
    url = ''
    url << (Rails.configuration.force_ssl ? 'https://' : 'http://')
    url << "#{account.subdomain}.#{ENV['YALTY_APP_DOMAIN']}"
    url << ":#{ENV['EMBER_PORT']}" if Rails.env == 'e2e-testing'
    url << '/account/export'
    url
  end
end
