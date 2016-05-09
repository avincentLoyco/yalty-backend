class JoinTableWithEffectiveTill
  attr_reader :join_table, :join_table_class, :account_id, :employee_id, :join_table_id

  def initialize(join_table_class, account, join_table_id = nil, employee_id = nil)
    @join_table_class = join_table_class
    @join_table = join_table_class.to_s.tableize
    @account_id = account.id
    @joint_table_id = join_table_id
    @employee_id = employee_id
  end

  def call
    ActiveRecord::Base.connection.select_all(
      case join_table_class
      when EmployeeTimeOffPolicy
        sql(category_condition_sql, '')
      when EmployeePresencePolicy
        sql('', start_day_order_sql)
      end
    ).to_ary
  end

  private

  def sql(extra_join_conditions, extra_select_attributes)
    "
      SELECT A.id, A.employee_id, A.effective_at::date, min(B.effective_at::date) AS effective_till
            #{extra_select_attributes}
      FROM #{join_table} AS A
        LEFT OUTER JOIN #{join_table} AS B
          ON A.employee_id = B.employee_id
          AND A.effective_at < B.effective_at
          INNER JOIN employees
            ON employees.account_id = B.employee_id
          #{extra_join_conditions}
      WHERE ( B.effective_at is null
        OR B.effective_at >= to_date('#{Time.zone.today}', 'YYYY-MM_DD')
        AND employees.account_id = #{account_id}
        #{specific_employee_sql}
        #{specific_join_table_instance_sql}
      GROUP BY  A.id;
    "
  end

  def category_condition_sql
    'AND A.time_off_category_id = B.time_off_category_id'
  end

  def start_day_order_sql
    ', A.start_day_order'
  end

  def specific_employee_sql
    employee_id.present? ? "AND A.employee_id = #{employee_id}" : ''
  end

  def specific_join_table_instance_sql
    joint_table_id.present? ? "AND A.id = #{joint_table_id}" : ''
  end
end
