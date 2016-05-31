class EmployeeCategoryPolicyFinder
  attr_reader :date, :day, :month

  def initialize(date)
    @date = date.to_s
    @day = date.day
    @month = date.month
  end

  def data_from_employees_with_employee_policy_for_day_and_month
    ActiveRecord::Base.connection.select_all(
      "
        #{employees_with_employee_policy_sql}
        #{and_in_day_and_month_sql} ;
      ").to_ary
  end

  def data_from_employees_with_employee_policy_with_previous_policy_of_different_type
    ActiveRecord::Base.connection.select_all(
      "
        #{info_of_previous_policies_of_different_type_for_employees_with_employee_policy} ;
      ").to_ary
  end

  private

  def info_of_previous_policies_of_different_type_for_employees_with_employee_policy
    "
      SELECT B.time_off_category_id, B.employee_id, B.account_id
      FROM
      (
        #{previous_employees_with_employee_policy_sql}
      ) AS A
      INNER JOIN
      (
        #{employees_with_employee_policy_sql}
      ) AS B
        ON A.time_off_category_id = B.time_off_category_id
        AND A.employee_id = B.employee_id
        AND A.policy_type != B.policy_type
    "
  end

  def employees_with_employee_policy_sql
    "
      SELECT etopa.employee_id, etopa.effective_at, top.time_off_category_id, top.policy_type,
        top.end_day, top.end_month, top.amount, top.start_day, top.start_month, top.years_to_effect,
        toc.account_id
      FROM
      (
        SELECT etop.effective_at, etop.employee_id, etop.time_off_policy_id,
          etop.time_off_category_id
        FROM employee_time_off_policies as etop
        WHERE etop.effective_at <= to_date('#{@date}', 'YYYY-MM_DD')
      ) AS etopa
        LEFT OUTER JOIN employee_time_off_policies AS etopb
          ON etopa.employee_id = etopb.employee_id
          AND etopa.time_off_category_id = etopb.time_off_category_id
          AND etopb.effective_at <= to_date('#{@date}', 'YYYY-MM_DD')
          AND etopa.effective_at < etopb.effective_at
          INNER JOIN time_off_policies AS top
            ON etopa.time_off_policy_id = top.id
            INNER JOIN time_off_categories AS toc
              ON top.time_off_category_id = toc.id
      WHERE etopb.effective_at is null
    "
  end

  def previous_employees_with_employee_policy_sql
    "
      SELECT etopa.employee_id, top.time_off_category_id, top.policy_type, top.end_day,
        top.end_month, top.amount, top.years_to_effect, toc.account_id
      FROM
      (
        SELECT etop.effective_at, etop.employee_id, etop.time_off_policy_id,
          etop.time_off_category_id
        FROM employee_time_off_policies as etop
        WHERE etop.effective_at < to_date('#{@date}', 'YYYY-MM_DD')
      ) AS etopa
        LEFT OUTER JOIN employee_time_off_policies AS etopb
          ON etopa.employee_id = etopb.employee_id
          AND etopa.time_off_category_id = etopb.time_off_category_id
          AND etopb.effective_at < to_date('#{@date}', 'YYYY-MM_DD')
          AND etopa.effective_at < etopb.effective_at
          INNER JOIN time_off_policies AS top
            ON etopa.time_off_policy_id = top.id
            INNER JOIN time_off_categories AS toc
              ON top.time_off_category_id = toc.id
      WHERE etopb.effective_at is null
    "
  end

  def and_in_day_and_month_sql
    " AND top.start_day = #{@day}
      AND top.start_month = #{@month}
    "
  end
end
