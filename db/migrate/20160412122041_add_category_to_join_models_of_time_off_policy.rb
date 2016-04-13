class AddCategoryToJoinModelsOfTimeOffPolicy < ActiveRecord::Migration
  class EmployeeTimeOffPolicy < ActiveRecord::Base
    belongs_to :time_off_policy
  end

  class WorkingPlaceTimeOffPolicy < ActiveRecord::Base
    belongs_to :time_off_policy
  end

  def change
    add_column :employee_time_off_policies, :time_off_category_id, :uuid
    add_column :working_place_time_off_policies, :time_off_category_id, :uuid

    EmployeeTimeOffPolicy.all.each do |etop|
      etop.update_attribute(:time_off_category_id, etop.time_off_policy.time_off_category_id)
    end

    WorkingPlaceTimeOffPolicy.all.each do |wptop|
      wptop.update_attribute(:time_off_category_id, wptop.time_off_policy.time_off_category_id)
    end
  end
end
