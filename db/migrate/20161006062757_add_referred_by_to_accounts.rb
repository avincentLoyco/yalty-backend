class AddReferredByToAccounts < ActiveRecord::Migration
  def change
    add_column :accounts, :referred_by, :string, foreign_key: true
  end
end
