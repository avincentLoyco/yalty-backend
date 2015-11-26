class UserMailerAccountsListJob
  @queue = :user_mailer_accounts_list

  def self.perform(email, accounts_subdomains)
    UserMailer.accounts_list(email, accounts_subdomains).deliver_later
  end
end
