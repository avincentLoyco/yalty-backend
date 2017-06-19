class AddStandardDayDurationToPresencePolicy < ActiveRecord::Migration
  def change
    add_column :presence_policies, :standard_day_duration, :integer
  end
end
