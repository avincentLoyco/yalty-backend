class AddDefaultFalseForResetWorkingPlacePresencePolicyPresencePolicy < ActiveRecord::Migration
  def change
    change_column_null :time_off_policies, :reset, false, false
    change_column_null :presence_policies, :reset, false, false
    change_column_null :working_places, :reset, false, false

    change_column_default :time_off_policies, :reset, false
    change_column_default :presence_policies, :reset, false
    change_column_default :working_places, :reset, false
  end
end
