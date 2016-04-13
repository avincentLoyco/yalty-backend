class AddPolicyAdditionsJob < ActiveJob::Base
  queue_as :policies_and_balances

  def perform
    today = Time.zone.today
    mixed_table_data =
      data_from_employees_with_employee_policy_for_day_and_month(today.day, today.month) +
      data_from_employees_with_working_place_policy_for_day_and_month(today.day, today.month)
    mixed_table_data.each do |hash|
      hash['policy_type'] == 'counter' ? manage_counter(hash) : manage_balancer(hash)
    end
  end

  private

  def employees_with_employee_policy_sql
    "
      SELECT etopa.employee_id, top.time_off_category_id, top.policy_type, top.end_day,
        top.end_month, top.amount, top.years_to_effect, top.years_passed, toc.account_id
      FROM employee_time_off_policies AS etopa
        LEFT OUTER JOIN employee_time_off_policies AS etopb
          ON etopa.employee_id = etopb.employee_id
          AND etopa.time_off_category_id = etopb.time_off_category_id
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
          SELECT employees.id, employees.working_place_id
          FROM employees
          LEFT OUTER JOIN employee_time_off_policies as t
          ON employees.id = t.employee_id
          WHERE t.employee_id IS NULL
        )  AS e
        INNER JOIN working_places AS wp
          ON wp.id = e.working_place_id
          INNER JOIN  working_place_time_off_policies AS wptopa
            ON wptopa.working_place_id = wp.id
          LEFT OUTER JOIN working_place_time_off_policies AS wptopb
            ON wptopa.working_place_id = wptopb.working_place_id
            AND wptopa.time_off_category_id = wptopb.time_off_category_id
            AND wptopa.effective_at < wptopb.effective_at
            INNER JOIN time_off_policies AS top
              ON wptopa.time_off_policy_id = top.id
              INNER JOIN time_off_categories AS toc
                ON top.time_off_category_id = toc.id
        WHERE wptopb.effective_at is null
    "
  end

  def and_in_day_and_month_sql(day, month)
    " AND top.start_day = #{day}
      AND top.start_month = #{month}
    "
  end

  def data_from_employees_with_working_place_policy_for_day_and_month(day, month)
    ActiveRecord::Base.connection.select_all(
      "
        #{employees_with_working_place_policy_sql}
        #{and_in_day_and_month_sql(day, month)} ;
      ").to_ary
  end

  def data_from_employees_with_employee_policy_for_day_and_month(day, month)
    ActiveRecord::Base.connection.select_all(
      "
        #{employees_with_employee_policy_sql}
        #{and_in_day_and_month_sql(day, month)} ;
      ").to_ary
  end

  def manage_counter(attributes_hash)
    options = { policy_credit_addition: true }
    CreateEmployeeBalance.new(
      attributes_hash['time_off_category_id'],
      attributes_hash['employee_id'],
      attributes_hash['account_id'],
      nil,
      options
    ).call
  end

  def manage_balancer(attributes_hash)
    options = options_for_balancer(attributes_hash)
    CreateEmployeeBalance.new(
      attributes_hash['time_off_category_id'],
      attributes_hash['employee_id'],
      attributes_hash['account_id'],
      attributes_hash['amount'],
      options
    ).call
  end

  def options_for_balancer(attributes_hash)
    {
      policy_credit_addition: true,
      validity_date: policy_end_date(
        attributes_hash['end_day'],
        attributes_hash['end_month'],
        attributes_hash['years_to_effect'],
        attributes_hash['years_passed)']
      )
    }
  end

  def policy_end_date(end_day, end_month, years_to_effect, years_passed)
    return nil if end_day.blank? && end_month.blank?
    add_years = years_to_effect > 1 ? years_to_effect : 1
    Date.new(Time.zone.today.year - years_passed + add_years, end_month, end_day)
  end
end
