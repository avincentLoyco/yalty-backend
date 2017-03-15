class AddUserLanguage < ActiveRecord::Migration
  def change
    add_column :account_users, :locale, :string
  end
end
