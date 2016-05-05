class JoinTableWithEffectiveTill
  attr_reader :join_table, :join_table_class

  def initialize(join_table_class)
    @join_table_class = join_table_class
    @join_table = join_table_class.to_s.tableize
  end

  def call
    ActiveRecord::Base.connection.select_all(
      if join_table == EmployeeTimeOffPolicy
        sql(category_condition_sql)
      else
        sql('')
      end
    ).to_ary
  end

  private

  def sql(extra_join_conditions)
    "
      SELECT A.id, A.employee_id, A.effective_at::date, min(B.effective_at::date) AS effective_till
      FROM #{join_table} AS A
        LEFT OUTER JOIN #{join_table} AS B
          ON A.employee_id = B.employee_id
          AND A.effective_at < B.effective_at
          #{extra_join_conditions}
      WHERE B.effective_at is null
        OR B.effective_at >= to_date('#{Time.zone.today}', 'YYYY-MM_DD')
      GROUP BY  A.id;
    "
  end

  def category_condition_sql
    'AND A.time_off_category_id = B.time_off_category_id'
  end
end
