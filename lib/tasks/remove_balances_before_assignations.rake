task remove_balances_before_assignations: [:environment] do
  ActiveRecord::Base.connection_pool.with_connection do
    oldest_etop_per_employee_and_category =
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

    oldest_etop_per_employee_and_category.each do |etop|
      etop.employee.employee_balances.where(time_off_category: etop.time_off_category)
          .where('effective_at < ?', etop.effective_at).delete_all
    end
  end
end
