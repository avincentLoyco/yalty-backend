class CreateAdditionsAndRemovals < ActiveJob::Base
  queue_as :policies_and_balances

  def perform
    active_employee_time_off_policies.each do |etop|
      ManageEmployeeBalanceAdditions.new(etop).call
    end
  end

  private

  def active_employee_time_off_policies
    EmployeeTimeOffPolicy.where(id: employee_time_off_policies_ids)
  end

  def employee_time_off_policies_ids
    ActiveRecord::Base.connection.execute(policies_query).map { |row| row["id"] }
  end

  def policies_query
    "
    SELECT policies.id FROM employee_time_off_policies policies
    INNER JOIN (
      SELECT time_off_category_id, time_off_policy_id, employee_id,
        max(effective_at) AS maxeffective
      FROM employee_time_off_policies
      WHERE effective_at <= '#{Time.zone.today}'
      GROUP BY time_off_category_id, employee_id, time_off_policy_id
    ) AS grouped
    INNER JOIN time_off_policies AS top
      ON top.id = grouped.time_off_policy_id
    ON policies.time_off_category_id = grouped.time_off_category_id
    AND policies.effective_at = grouped.maxeffective
    AND policies.employee_id = grouped.employee_id
    WHERE top.start_day = '#{Time.zone.today.day}'
    AND top.start_month = '#{Time.zone.today.month}'
    "
  end
end
