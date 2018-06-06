class UserMailerPreview < ActionMailer::Preview
  def account_creation_confirmation_preview
    user = Account::User.find_by(email: "some_email@mail.com")
    UserMailer.account_creation_confirmation(user.id)
  end

  def user_invitation_preview
    user = Account::User.find_by(email: "some_email@mail.com")
    login_url = "=== LOGIN URL ==="
    UserMailer.user_invitation(user.id, login_url)
  end

  def accounts_list_preview
    email = "specified_email@domain.com"
    account_ids = Account.all
    UserMailer.accounts_list(email, account_ids)
  end

  def reset_password_preview
    user = Account::User.find_by(email: "some_email@mail.com")
    UserMailer.reset_password(user.id)
  end
end
