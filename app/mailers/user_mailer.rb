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

  def accounts_list(email, account_ids)
    @email = email
    @accounts = Account.where(id: account_ids).readonly

    if @accounts.present?
      locale = @accounts.first.default_locale
    else
      locale = I18n.default_locale
    end

    I18n.with_locale(locale) do
      mail to: @email
    end
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
