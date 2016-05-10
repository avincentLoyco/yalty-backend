class JoinTableWithEffectiveTill
  attr_reader :join_table, :join_table_class, :account_id, :employee_id, :join_table_id,
    :resource_id

  def initialize(join_table_class, account_id, resource_id = nil, employee_id = nil, join_table_id = nil)
    @join_table_class = join_table_class
    @join_table = join_table_class.to_s.tableize
    @account_id = account.id
    @join_table_id = join_table_id
    @employee_id = employee_id
    @resource_id = resource_id
  end

  def call
    ActiveRecord::Base.connection.select_all(
      case join_table_class.to_s
      when EmployeeTimeOffPolicy.to_s
        sql(category_condition_sql, '', specific_time_off_policy_sql)
      when EmployeePresencePolicy.to_s
        sql('', order_of_start_day_sql, specific_presence_policy_sql)
      end
    ).to_ary
  end

  private

  def sql(extra_join_conditions, extra_select_attributes, extra_where_conditions)
    " SELECT A.id, A.employee_id, A.effective_at, A.effective_till #{extra_select_attributes}
      FROM(
        SELECT A.id, A.employee_id, A.effective_at::date, min(B.effective_at::date)
               AS effective_till #{extra_select_attributes}
        FROM #{join_table} AS A
          LEFT OUTER JOIN #{join_table} AS B
            ON A.employee_id = B.employee_id
            AND A.effective_at < B.effective_at
            #{extra_join_conditions}
          INNER JOIN employees
            ON employees.id = A.employee_id
            AND employees.account_id = '#{account_id}'
          #{specific_employee_sql}
          #{specific_join_table_instance_sql}
          #{extra_where_conditions}
        GROUP BY  A.id
      ) AS A
      WHERE A.effective_till is null
        OR A.effective_till >= to_date('#{Time.zone.today}', 'YYYY-MM_DD');"
  end

  def category_condition_sql
    'WHERE A.time_off_category_id = B.time_off_category_id'
  end

  def order_of_start_day_sql
    ', A.order_of_start_day'
  end

  def specific_presence_policy_sql
    resource_id.present? ? "AND A.presence_policy_id = '#{resource_id}'" : ''
  end

  def specific_time_off_policy_sql
    resource_id.present? ? "AND A.time_off_policy_id = '#{resource_id}'" : ''
  end

  def specific_employee_sql
    employee_id.present? ? "WHERE A.employee_id = '#{employee_id}'" : ''
  end

  def specific_join_table_instance_sql
    join_table_id.present? ? "WHERE A.id = '#{join_table_id}'" : ''
  end
end
