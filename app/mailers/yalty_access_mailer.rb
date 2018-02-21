class YaltyAccessMailer < ApplicationMailer
  helper_method :account

  def access_enable(account)
    @account = account

    I18n.with_locale(@account.default_locale) do
      mail to: ENV["YALTY_ACCESS_EMAIL"]
    end
  end

  def access_disable(account)
    @account = account

    I18n.with_locale(@account.default_locale) do
      mail to: ENV["YALTY_ACCESS_EMAIL"]
    end
  end

  private

  attr_reader :account
end
