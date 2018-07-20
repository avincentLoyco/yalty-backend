class YaltyAccessMailerPreview < ActionMailer::Preview
  def access_enable_preview
    account = Account.find_by(subdomain: "seed")
    YaltyAccessMailer.access_enable(account)
  end

  def access_disable_preview
    account = Account.find_by(subdomain: "seed")
    YaltyAccessMailer.access_disable(account)
  end
end
