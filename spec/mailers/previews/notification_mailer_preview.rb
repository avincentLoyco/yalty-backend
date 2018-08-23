class NotificationMailerPreview < ActionMailer::Preview
  def time_off_request
    user = Account::User.last

    NotificationMailer.time_off_request(user, TimeOff.last)
  end

  def time_off_approved
    user = Account::User.last

    NotificationMailer.time_off_approved(user, TimeOff.last)
  end

  def time_off_declined
    user = Account::User.last

    NotificationMailer.time_off_declined(user, TimeOff.last)
  end
end
