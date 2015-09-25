class AddSettingsToAccounts < ActiveRecord::Migration
  def change
    add_column :accounts, :default_locale, :string, default: 'en'
    add_column :accounts, :timezone, :string
  end
end
