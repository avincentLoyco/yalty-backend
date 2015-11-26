class UserMailerCredentialsJob
  @queue = :user_mailer_credentials

  def self.perform(user_id, password, url)
    UserMailer.credentials(user_id, password, url).deliver_later
  end
end
