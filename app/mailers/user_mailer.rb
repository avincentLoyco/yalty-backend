class UserMailer < ApplicationMailer
  def credentials(user_id, password, url)
    user = Account::User.find(user_id)

    body = "
      Your password: #{password}
      Your account URL: #{url}

      Please remember to change your password!
    "

    send_mail(user.email, 'Your credentials', body)
  end

  def accounts_list(email, accounts_subdomains)
    body = "
      You have access to accounts:
      #{accounts_subdomains.join(".#{ENV['YALTY_BASE_URL']}, ")}
    "

    send_mail(email, 'Your accounts', body)
  end

  def reset_password(user_id, url)
    user = Account::User.find(user_id)

    body = "
      You can change your password at this url:

      #{url}
    "

    mail(
      to:           user.email,
      subject:      'Your reset password token',
      body:         body,
      content_type: 'text/plain'
    )
  end
end
