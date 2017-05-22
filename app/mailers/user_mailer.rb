class UserMailer < ApplicationMailer
  def account_creation_confirmation(user_id)
    @user = Account::User.where(id: user_id).includes(:account).readonly.first!

    I18n.with_locale(@user.account.default_locale) do
      mail to: @user.email
    end
  end

  def user_invitation(user_id, login_url)
    @user = Account::User.where(id: user_id).includes(:account).readonly.first!
    @login_url = login_url

    I18n.with_locale(@user.account.default_locale) do
      mail to: @user.email
    end
  end

  def accounts_list(email, account_ids)
    @email = email
    @accounts = Account.where(id: account_ids).readonly

    locale = if @accounts.present?
               @accounts.first.default_locale
             else
               I18n.default_locale
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
end
