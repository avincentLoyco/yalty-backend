class AddResetFlagToPoliciesAndWorkingPlaces < ActiveRecord::Migration
  def change
    add_column :working_places,    :reset, :boolean
    add_column :presence_policies, :reset, :boolean
    add_column :time_off_policies, :reset, :boolean
    execute <<-SQL
      UPDATE working_places SET reset = false
    SQL
    change_column_null :working_places, :reset, true, false
    execute <<-SQL
      UPDATE presence_policies SET reset = false
    SQL
    change_column_null :presence_policies, :reset, true, false
    execute <<-SQL
      UPDATE time_off_policies SET reset = false
    SQL
    change_column_null :time_off_policies, :reset, true, false
  end
end
