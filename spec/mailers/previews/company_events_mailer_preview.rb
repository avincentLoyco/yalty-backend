class CompanyEventsMailerPreview < ActionMailer::Preview
  def event_changed_preview
    account = Account.find_by(subdomain: "seed")
    user = account.users.find_by(role: "user")
    controller_action = "create"

    company_event = account.company_events.first

    CompanyEventsMailer.event_changed(account, company_event, user.id, controller_action)
  end
end
