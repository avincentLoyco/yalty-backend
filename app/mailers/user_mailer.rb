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
      #{accounts_subdomains.join(', ')}
    "

    send_mail(email, 'Your accounts', body)
  end
end
