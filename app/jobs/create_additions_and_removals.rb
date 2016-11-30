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
    """
    SELECT policies.id FROM employee_time_off_policies policies
    INNER JOIN (
      SELECT time_off_category_id, employee_id, max(effective_at) AS maxeffective
      FROM employee_time_off_policies
      WHERE effective_at <= CURRENT_DATE
      GROUP BY time_off_category_id, employee_id
    ) grouped
    ON policies.time_off_category_id = grouped.time_off_category_id
    AND policies.effective_at = grouped.maxeffective
    AND policies.employee_id = grouped.employee_id;
    """
  end
end
