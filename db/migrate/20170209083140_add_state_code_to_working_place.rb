class AddStateCodeToWorkingPlace < ActiveRecord::Migration
  def change
    add_column :working_places, :state_code, :string, limit: 60
  end
end
