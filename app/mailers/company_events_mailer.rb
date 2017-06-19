class CompanyEventsMailer < ApplicationMailer
  helper_method :url_for_company_event

  def event_changed(account, company_event, user_id, controller_action)
    @account = account
    @company_event = company_event
    @action_name = I18n.t("company_events_mailer.action_#{controller_action}")

    I18n.with_locale(@account.default_locale) do
      mail(
        to: recipients(@account, user_id),
        subject: default_i18n_subject(company_name: account.company_name)
      )
    end
  end

  private

  def recipients(account, user_id)
    roles = %w(account_owner account_administrator yalty)
    account.users.where.not(id: user_id).where(role: roles).pluck(:email)
  end

  def url_for_company_event(account, company_event)
    url = subdomain_url_for(account)
    url << "/company_events/#{company_event.id}"
    url
  end
end
