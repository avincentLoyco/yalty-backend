class YaltyAccessMailer < ApplicationMailer
  helper_method :account

  def access_enable(account)
    @account = account

    mail to: ENV['YALTY_ACCESS_EMAIL']
  end

  def access_disable(account)
    @account = account

    mail to: ENV['YALTY_ACCESS_EMAIL']
  end

  private

  attr_reader :account
end
