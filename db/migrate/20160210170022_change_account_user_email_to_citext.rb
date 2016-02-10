class ChangeAccountUserEmailToCitext < ActiveRecord::Migration
  def change
    enable_extension 'citext'

    change_column :account_users, :email,  :citext
  end
end
