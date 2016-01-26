class SetAccountManagerForAllUsers < ActiveRecord::Migration
  def up
    Account::User.all.each { |user| user.update(account_manager: true) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
