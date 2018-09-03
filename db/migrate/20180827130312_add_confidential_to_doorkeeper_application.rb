class AddConfidentialToDoorkeeperApplication < ActiveRecord::Migration
  def change
    add_column(:oauth_applications, :confidential, :boolean)
    change_column_default :oauth_applications, :confidential, true
    execute("UPDATE oauth_applications SET confidential = TRUE")
    change_column_null :oauth_applications, :confidential, false
  end
end
