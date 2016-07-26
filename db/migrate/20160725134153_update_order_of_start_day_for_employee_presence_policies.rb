class UpdateOrderOfStartDayForEmployeePresencePolicies < ActiveRecord::Migration
  def change
    EmployeePresencePolicy.all.each do |employee_presence_policy|
      start_order = employee_presence_policy.effective_at.cwday
      employee_presence_policy.update!(order_of_start_day: start_order)
    end
  end
end
