namespace :db do
  namespace :cleanup do
    desc "Create missing balances for all employees"
    task create_missing_balances: [:environment] do
      ActiveRecord::Base.connection_pool.with_connection do
        older_etop_per_employee_and_category =
          EmployeeTimeOffPolicy
          .joins("
            LEFT OUTER JOIN
            (
              SELECT etop.id, etop.time_off_category_id, etop.employee_id,
                     MIN(etop.effective_at) oldest_effective_at
              FROM employee_time_off_policies as etop
              GROUP BY  etop.id, etop.time_off_category_id, etop.employee_id
            ) AS etopb
             ON employee_time_off_policies.time_off_category_id = etopb.time_off_category_id
             AND employee_time_off_policies.employee_id = etopb.employee_id
          ")
          .where("
            etopb.time_off_category_id IS NOT NULL
            AND employee_time_off_policies.effective_at = etopb.oldest_effective_at
          ")

        older_etop_per_employee_and_category.find_each do |etop|
          ManageEmployeeBalanceAdditions.new(etop, false).call
        end
      end
    end
  end
end
