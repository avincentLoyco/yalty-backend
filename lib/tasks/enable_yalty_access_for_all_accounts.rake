desc "Enable yalty access for all accounts"
task enable_yalty_access_for_all_accounts: [:environment] do
  account_ids_with_yalty_access =
    Account::User
      .where(role: "yalty")
      .select(:account_id)
      .pluck(:account_id)

  account_ids_without_yalty_access =
    Account
      .where.not(id: account_ids_with_yalty_access)
      .select(:id)
      .pluck(:id)

  current_time = Time.current

  users_to_create = account_ids_without_yalty_access.map do |account_id|
    <<~SQL
      (
        '#{account_id}',
        '#{ENV["YALTY_ACCESS_EMAIL"]}',
        '#{ENV["YALTY_ACCESS_PASSWORD_DIGEST"]}',
        'yalty',
        '#{current_time}',
        '#{current_time}'
      )
    SQL
  end.join(", ").delete("\n")

  # I used custom SQL query to avoid multiple db calls caused by validations
  ActiveRecord::Base.connection.execute(
    <<~SQL
      INSERT INTO account_users (account_id, email, password_digest, role, created_at, updated_at)
      VALUES #{users_to_create}
    SQL
  )
end
