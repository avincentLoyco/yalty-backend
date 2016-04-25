class EmployeeCategoryPolicyFinder
  attr_reader :date, :day, :month

  def initialize(date)
    @date = date.to_s
    @day = date.day
    @month = date.month
  end

  def data_from_employees_with_working_place_policy_for_day_and_month
    ActiveRecord::Base.connection.select_all(
      "
        #{employees_with_working_place_policy_sql}
        #{and_in_day_and_month_sql} ;
      ").to_ary
  end

  def data_from_employees_with_employee_policy_for_day_and_month
    ActiveRecord::Base.connection.select_all(
      "
        #{employees_with_employee_policy_sql}
        #{and_in_day_and_month_sql} ;
      ").to_ary
  end

  def data_from_employees_with_employee_policy_for_effective_date_at
    ActiveRecord::Base.connection.select_all(
      "
        #{employees_with_employee_policy_sql}
        #{where_etop_effective_date_in_date_sql} ;
      ").to_ary
  end

  def data_from_employees_with_employee_policy_with_previous_policy_of_different_type
    ActiveRecord::Base.connection.select_all(
      "
        #{info_of_previous_policies_of_different_type_for_employees_with_employee_policy} ;
      ").to_ary
  end

  def data_from_employees_with_working_place_policy_with_previous_policy_of_different_type
    ActiveRecord::Base.connection.select_all(
      "
        #{info_of_previous_policies_of_different_type_for_employees_with_working_place_policy} ;
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
      UNION
      SELECT C.time_off_category_id, C.employee_id, C.account_id
      FROM
      (
        #{previous_employees_with_employee_policy_sql}
      ) AS C
      INNER JOIN
      (
        #{employees_with_working_place_policy_sql}
      ) AS D
        ON C.time_off_category_id = D.time_off_category_id
        AND C.employee_id = D.employee_id
        AND C.policy_type != D.policy_type
    "
  end

  def info_of_previous_policies_of_different_type_for_employees_with_working_place_policy
    "
      SELECT C.time_off_category_id, C.employee_id, C.account_id
      FROM
      (
        #{previous_employees_with_working_place_policy_sql}
      ) AS A
      INNER JOIN
      (
        #{employees_with_working_place_policy_sql}
      ) AS C
        ON A.time_off_category_id = C.time_off_category_id
        AND A.employee_id = C.employee_id
        AND A.policy_type != C.policy_type
    "
  end

  def employees_with_employee_policy_sql
    "
      SELECT etopa.employee_id, top.time_off_category_id, top.policy_type, top.end_day,
        top.end_month, top.amount, top.years_to_effect, top.years_passed, toc.account_id
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

  def employees_with_working_place_policy_sql
    "
      SELECT e.id as employee_id, top.time_off_category_id, top.policy_type, top.end_day,
        top.end_month, top.amount, top.years_to_effect, top.years_passed, toc.account_id
        FROM
        (
          SELECT DISTINCT employees.id, employees.working_place_id
          FROM employees
          LEFT OUTER JOIN employee_time_off_policies as t
          ON employees.id = t.employee_id
          AND t.effective_at < to_date('#{@date}', 'YYYY-MM_DD')
          WHERE t.employee_id IS NULL
        )  AS e
        INNER JOIN working_places AS wp
          ON wp.id = e.working_place_id
          INNER JOIN  working_place_time_off_policies AS wptopa
            ON wptopa.working_place_id = wp.id
            AND wptopa.effective_at <= to_date('#{@date}', 'YYYY-MM_DD')
          LEFT OUTER JOIN working_place_time_off_policies AS wptopb
            ON wptopa.working_place_id = wptopb.working_place_id
            AND wptopa.time_off_category_id = wptopb.time_off_category_id
            AND wptopb.effective_at <= to_date('#{@date}', 'YYYY-MM_DD')
            AND wptopa.effective_at < wptopb.effective_at
            INNER JOIN time_off_policies AS top
              ON wptopa.time_off_policy_id = top.id
              INNER JOIN time_off_categories AS toc
                ON top.time_off_category_id = toc.id
        WHERE wptopb.effective_at is null
    "
  end

  def previous_employees_with_employee_policy_sql
    "
      SELECT etopa.employee_id, top.time_off_category_id, top.policy_type, top.end_day,
        top.end_month, top.amount, top.years_to_effect, top.years_passed, toc.account_id
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

  def previous_employees_with_working_place_policy_sql
    "
      SELECT e.id as employee_id, top.time_off_category_id, top.policy_type, top.end_day,
        top.end_month, top.amount, top.years_to_effect, top.years_passed, toc.account_id
        FROM
        (
          SELECT DISTINCT employees.id, employees.working_place_id
          FROM employees
          LEFT OUTER JOIN employee_time_off_policies as t
          ON employees.id = t.employee_id
          AND t.effective_at < to_date('#{@date}', 'YYYY-MM_DD')
          WHERE t.employee_id IS NULL
        )  AS e
        INNER JOIN working_places AS wp
          ON wp.id = e.working_place_id
          INNER JOIN  working_place_time_off_policies AS wptopa
            ON wptopa.working_place_id = wp.id
            AND wptopa.effective_at < to_date('#{@date}', 'YYYY-MM_DD')
          LEFT OUTER JOIN working_place_time_off_policies AS wptopb
            ON wptopa.working_place_id = wptopb.working_place_id
            AND wptopa.time_off_category_id = wptopb.time_off_category_id
            AND wptopb.effective_at < to_date('#{@date}', 'YYYY-MM_DD')
            AND wptopa.effective_at < wptopb.effective_at
            INNER JOIN time_off_policies AS top
              ON wptopa.time_off_policy_id = top.id
              INNER JOIN time_off_categories AS toc
                ON top.time_off_category_id = toc.id
        WHERE wptopb.effective_at is null
    "
  end

  def and_in_day_and_month_sql
    " AND top.start_day = #{@day}
      AND top.start_month = #{@month}
    "
  end

  def and_etop_effective_date_in_date_sql
    " AND etopa.effective_at = to_date('#{@date}', 'YYYY-MM_DD')"
  end

  def and_wptop_effective_date_in_date_sql
    " AND wptopa.effective_at = to_date('#{@date}', 'YYYY-MM_DD')"
  end
end
