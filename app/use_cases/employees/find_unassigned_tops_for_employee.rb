# frozen_string_literal: true

module Employees
  class FindUnassignedTopsForEmployee
    def call(employee)
      # TODO: extract both db calls to repositories
      assigned_top_ids = employee.time_off_policy_ids
      account_tops = employee.account.time_off_policies.not_reset

      account_tops.reject do |top|
        assigned_top_ids.include?(top.id)
      end
    end
  end
end
