class ServiceRequestMailerPreview < ActionMailer::Preview
  def quote_request_preview
    ServiceRequestMailer.quote_request(account, owner, services)
  end

  def book_request_preview
    ServiceRequestMailer.book_request(account, owner, services)
  end

  private

  def account
    Account.find_by(subdomain: "seed")
  end

  def owner
    account.users.find_by(role: "account_owner")
  end

  def services
    @services ||=
      JSON.parse(
        Rails.root.join("spec", "fixtures", "files", "services_request.json").read,
        symbolize_names: true
      )
  end
end
