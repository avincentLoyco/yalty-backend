class AddEmployeeEventToEmployeePresencePolicyAndEmployeeTimeOffPolicy < ActiveRecord::Migration
  def change
    add_reference :employee_presence_policies, :employee_event, type: :uuid, index: true, foreign_key: true
    add_reference :employee_time_off_policies, :employee_event, index: true, type: :uuid, foreign_key: true
  end
end
