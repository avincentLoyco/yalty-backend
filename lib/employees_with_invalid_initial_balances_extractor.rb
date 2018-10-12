# https://yaltyapp.atlassian.net/browse/YA-2031
# https://yaltyapp.atlassian.net/browse/YA-2065
# This file was created to find all employees with invalid initial balances and was never used.
# There's a chance that not every single invalid balance will be found.
# The file is kept for future reference.

class EmployeesWithInvalidInitialBalancesExtractor
  class << self
    def call
      Employee
        .joins(:account, :user)
        .where(id: employees_with_invalid_initial_balances_ids)
        .select { |e| !e.employee_balances.any? { |bal| bal.balance_type == "reset" }}
        .group_by(&:account)
    end

    private

    def employees_with_invalid_initial_balances_ids
      Employee::Balance
        .joins(:time_off_category)
        .where(employee_id: employees_without_manual_adjustments_ids)
        .where(time_off_categories: { name: "vacation" })
        .order(:employee_id, :effective_at)
        .group_by(&:employee_id)
        .each_with_object({}) do |(k, v), hash|
          hash[k] = v
            .group_by { |x| x.effective_at.to_date }
            .first[1]
            .inject(0) { |sum, x| sum + x.balance }
        end
        .select { |_k,v| v.zero? }
        .keys
    end

    def employees_without_manual_adjustments_ids # rubocop:disable Metrics/MethodLength
      ActiveRecord::Base.connection.execute(
        <<-SQL
          SELECT DISTINCT e.id
          FROM employee_balances bal
            JOIN employees e ON e.id = bal.employee_id
            JOIN account_users u ON u.id = e.account_user_id
            JOIN accounts acc ON acc.id = u.account_id
            JOIN time_off_categories cat ON bal.time_off_category_id = cat.id
          WHERE e.id NOT IN (
        		-- Employees who have received "resource_amount" at least once before 2018
        		SELECT DISTINCT bal.employee_id FROM employee_balances bal
              JOIN time_off_categories cat ON bal.time_off_category_id = cat.id
        		WHERE cat.name = 'vacation'
        		AND (
        			(bal.effective_at < DATE'#{migration_date}' AND bal.resource_amount > 0)
        			OR
        			(bal.effective_at < DATE'#{migration_date}' AND bal.manual_amount > 0)
        			OR
        			(bal.effective_at > DATE'#{migration_date - 1.day}' AND bal.balance_type='manual_adjustment')
        		)
        	)
        	AND (
            SELECT count(tmp.employee_id)
            FROM employee_balances tmp
            WHERE tmp.effective_at < DATE'#{migration_date}'
            AND tmp.employee_id = bal.employee_id
          ) > 0
        	AND u.email NOT LIKE '%astrocast%'
          AND u.email NOT LIKE '%yalty%'
          AND u.email NOT LIKE '%loyco%'
          AND u.email NOT LIKE '%monterail%'
          AND u.email NOT LIKE '%example%'
        	AND acc.subdomain NOT LIKE '%example%'
          AND acc.subdomain NOT LIKE '%exemple%'
          AND acc.subdomain NOT LIKE '%monterail%'
          AND acc.subdomain NOT LIKE '%demo%'
          AND acc.subdomain NOT LIKE '%test%'
        	AND cat.name = 'vacation'
        SQL
      ).map { |e| e["id"] }
    end

    def migration_date
      Rails.configuration.migration_date
    end
  end
end
