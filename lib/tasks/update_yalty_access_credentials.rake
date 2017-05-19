desc 'Update credentials of users with yalty role using current environment'
task update_yalty_access_credentials: [:environment] do
  Account::User.where(role: 'yalty').update_all(
    email: ENV['YALTY_ACCESS_EMAIL'],
    password_digest: ENV['YALTY_ACCESS_PASSWORD_DIGEST']
  )
end
