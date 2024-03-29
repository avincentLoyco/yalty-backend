class JoinTableWithEffectiveTill
  attr_reader :join_table, :join_table_class, :account_id, :employees_ids, :join_table_id,
    :resource_id, :effective_till_from_date, :effective_at_till_date

  def initialize(
    join_table_class,
    account_id = nil,
    resource_id = nil,
    employees_ids = nil,
    join_table_id = nil,
    effective_till_from_date = Time.zone.today,
    effective_at_till_date = nil
  )
    @join_table_class = join_table_class
    @join_table = join_table_class.to_s.tableize
    @account_id = account_id
    @join_table_id = join_table_id
    @employees_ids = employees_ids.present? ? process_employee_input(employees_ids) : nil
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
        sql("", specific_presence_policy_sql)
      when EmployeeWorkingPlace.to_s
        sql("", specific_working_place_sql)
      end
    ).to_ary
  end

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
            #{specific_account_sql}
        #{specific_employee_sql}
        #{specific_join_table_instance_sql}
        #{extra_where_conditions}
        GROUP BY A.id
      ) AS B
      #{conditional}
      ORDER BY B.effective_at;"
  end

  private

  def process_employee_input(input)
    input.is_a?(Array) ? convert_array_to_sql(input) : convert_array_to_sql([input])
  end

  def convert_array_to_sql(array)
    "('#{array.join("','")}')"
  end

  def conditional
    conditions = [effective_till_after_date_sql, effective_at_before_date_sql].compact.join(" AND ")
    conditions.empty? ? "" : " WHERE #{conditions}"
  end

  def effective_till_after_date_sql
    return unless effective_till_from_date.present?
    "(B.effective_till is null
     OR B.effective_till >= to_date('#{effective_till_from_date}', 'YYYY-MM_DD'))"
  end

  def category_condition_sql
    "AND A.time_off_category_id = B.time_off_category_id"
  end

  def effective_at_before_date_sql
    effective_at_till_date.present? ? " B.effective_at <= '#{effective_at_till_date}'" : nil
  end

  def specific_account_sql
    account_id.present? ? "AND employees.account_id = '#{account_id}'" : ""
  end

  def specific_presence_policy_sql
    resource_id.present? ? "AND A.presence_policy_id = '#{resource_id}'" : ""
  end

  def specific_time_off_policy_sql
    resource_id.present? ? "AND A.time_off_policy_id = '#{resource_id}'" : ""
  end

  def specific_working_place_sql
    resource_id.present? ? "AND A.working_place_id = '#{resource_id}'" : ""
  end

  def specific_employee_sql
    employees_ids.present? ? "WHERE A.employee_id IN #{employees_ids}" : ""
  end

  def specific_join_table_instance_sql
    join_table_id.present? ? "WHERE A.id = '#{join_table_id}'" : ""
  end
end
