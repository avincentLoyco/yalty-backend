class JoinTableWithEffectiveTill
  attr_reader :join_table, :join_table_class, :account_id, :employee_id, :join_table_id,
    :resource_id, :effective_till_from_date, :effective_at_till_date

  def initialize(
    join_table_class,
    account_id,
    resource_id = nil,
    employee_id = nil,
    join_table_id = nil,
    effective_till_from_date = Time.zone.today,
    effective_at_till_date = nil
  )
    @join_table_class = join_table_class
    @join_table = join_table_class.to_s.tableize
    @account_id = account_id
    @join_table_id = join_table_id
    @employee_id = employee_id
    @resource_id = resource_id
    @effective_till_from_date = effective_till_from_date
    @effective_at_till_date = effective_at_till_date
  end

  def call
    ActiveRecord::Base.connection.select_all(
      case join_table_class.to_s
      when EmployeeTimeOffPolicy.to_s
        sql(category_condition_sql, specific_time_off_policy_sql)
      when EmployeePresencePolicy.to_s
        sql('', specific_presence_policy_sql)
      when EmployeeWorkingPlace.to_s
        sql('', specific_working_place_sql)
      end
    ).to_ary
  end

  private

  def sql(extra_join_conditions, extra_where_conditions)
    " SELECT B.*
      FROM(
        SELECT A.*, min(B.effective_at) - integer '1'
               AS effective_till
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
      ) AS B
      WHERE ( B.effective_till is null
              OR B.effective_till >= to_date('#{effective_till_from_date}', 'YYYY-MM_DD')
            )
        #{effective_at_before_date_sql}
      ORDER BY B.effective_at;"
  end

  def category_condition_sql
    'AND A.time_off_category_id = B.time_off_category_id'
  end

  def effective_at_before_date_sql
    effective_at_till_date.present? ? "AND B.effective_at <= '#{effective_at_till_date}'" : ''
  end

  def specific_presence_policy_sql
    resource_id.present? ? "AND A.presence_policy_id = '#{resource_id}'" : ''
  end

  def specific_time_off_policy_sql
    resource_id.present? ? "AND A.time_off_policy_id = '#{resource_id}'" : ''
  end

  def specific_working_place_sql
    resource_id.present? ? "AND A.working_place_id = '#{resource_id}'" : ''
  end

  def specific_employee_sql
    employee_id.present? ? "WHERE A.employee_id = '#{employee_id}'" : ''
  end

  def specific_join_table_instance_sql
    join_table_id.present? ? "WHERE A.id = '#{join_table_id}'" : ''
  end
end
