class UserMailer < ApplicationMailer
  helper_method :subdomain_url_for

  def account_creation_confirmation(user_id, password)
    @user = Account::User.where(id: user_id).includes(:account).readonly.first!
    @user.password = password

    I18n.with_locale(@user.account.default_locale) do
      mail to: @user.email
    end
  end

  def credentials(user_id, password)
    @user = Account::User.where(id: user_id).includes(:account).readonly.first!
    @user.password = password

    I18n.with_locale(@user.account.default_locale) do
      mail to: @user.email
    end
  end

  def accounts_list(email, accounts_subdomains)
    body = "
      You have access to accounts:
      #{accounts_subdomains.join(".#{ENV['YALTY_APP_DOMAIN']}, ")}
    "

    send_mail(email, 'Your accounts', body)
  end

  def reset_password(user_id)
    @user = Account::User.where(id: user_id).includes(:account).readonly.first!

    I18n.with_locale(@user.account.default_locale) do
      mail to: @user.email
    end
  end

  private

  def subdomain_url_for(account)
    "https://#{account.subdomain}.#{ENV['YALTY_APP_DOMAIN']}"
  end
end
