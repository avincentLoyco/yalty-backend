class AddNameToTimeOffPolicy < ActiveRecord::Migration
  def change
    add_column :time_off_policies, :name, :string, null: false
  end
end
