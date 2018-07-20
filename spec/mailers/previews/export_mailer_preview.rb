class ExportMailerPreview < ActionMailer::Preview
  def archive_generation
    account = Account.find_by(subdomain: "seed")
    ExportMailer.archive_generation(account)
  end
end
