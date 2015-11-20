class UserMailer < ApplicationMailer
  def credentials(user_id, password, url)
    user = Account::User.find(user_id)

    body = "
      Your password: #{password}
      Your account URL: #{url}

      Please remember to change your password!
    "
    mail(
      to:           user.email,
      subject:      'Your credentials',
      body:         body,
      content_type: 'text/plain'
    )
  end
end
