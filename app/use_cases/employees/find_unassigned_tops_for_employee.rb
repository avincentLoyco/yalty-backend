# frozen_string_literal: true

module Employees
  class FindUnassignedTopsForEmployee
    def call(employee)
      # TODO: extract to repository
      employee.account.time_off_policies.not_reset.counters
        .where("time_off_policies.id not in
          (
            SELECT top.id FROM time_off_policies AS top
            JOIN employee_time_off_policies AS etop ON etop.time_off_policy_id = top.id
            JOIN employees AS e ON e.id = etop.employee_id
            WHERE e.id  = ?
          )", employee.id)
    end
  end
end
