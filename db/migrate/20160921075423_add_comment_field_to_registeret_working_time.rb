class AddCommentFieldToRegisteretWorkingTime < ActiveRecord::Migration
  def change
    add_column :registered_working_times, :comment, :text
  end
end
