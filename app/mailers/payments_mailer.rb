class PaymentsMailer < ApplicationMailer
  helper_method :payments_url_for, :in_chf
  default from: "yalty <#{ENV["YALTY_BILLING_EMAIL"]}>"

  def payment_succeeded(invoice_id)
    @invoice = Invoice.find(invoice_id)
    account = @invoice.account
    customer = Stripe::Customer.retrieve(account.customer_id)
    @card = customer.sources.find { |src| src.id.eql?(customer.default_source) }
    @next_payment_date = Time.zone.at(customer.subscriptions.first.current_period_end)
    @active_employees_count = account.employees.chargeable_at_date(Time.zone.tomorrow).count

    I18n.with_locale(account.default_locale) do
      attachments[@invoice.generic_file.file_file_name] = File.read(@invoice.generic_file.file.path)
      mail(
        to: recipients(account),
        subject: default_i18n_subject(company_name: account.company_name)
      )
    end
  end

  def payment_failed(invoice_id)
    @invoice = Invoice.find(invoice_id)
    account = @invoice.account
    customer = Stripe::Customer.retrieve(account.customer_id)
    @card = customer.sources.find { |src| src.id.eql?(customer.default_source) }

    I18n.with_locale(account.default_locale) do
      mail(
        to: recipients(account),
        subject: default_i18n_subject(company_name: account.company_name)
      )
    end
  end

  def subscription_canceled(account_id)
    @account = Account.find(account_id)

    I18n.with_locale(@account.default_locale) do
      mail(
        to: recipients(@account),
        subject: default_i18n_subject(company_name: @account.company_name)
      )
    end
  end

  private

  def recipients(account)
    return account.invoice_emails if account.invoice_emails.present?
    account.users.where(role: "account_owner").pluck(:email)
  end

  def payments_url_for(account)
    url = ""
    url << (Rails.configuration.force_ssl ? "https://" : "http://")
    url << "#{account.subdomain}.#{ENV["YALTY_APP_DOMAIN"]}"
    url << ":#{ENV["EMBER_PORT"]}" if Rails.env == "e2e-testing"
    url << "/account/payment/settings"
    url
  end

  def in_chf(amount)
    amount = 0 unless amount.present?
    format("%.2f", amount / 100.00)
  end
end
