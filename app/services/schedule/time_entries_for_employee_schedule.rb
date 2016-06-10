class TimeEntriesForEmployeeSchedule
  attr_reader :employee, :start_date, :end_date, :time_entries_hash

  def initialize(employee, start_date, end_date)
    @employee = employee
    @start_date = start_date
    @end_date = end_date
    @time_entries_hash = {}
  end

  def call
    fetch_usefull_info
  end

  private

  def fill_time_entries_hash
    fetch_usefull_info.each do |entry_hash|
      # TODO
    end
  end

  def fetch_usefull_info
    ActiveRecord::Base.connection.select_all(
      active_time_entries_with_day_order_and_effective_dates_sql
    ).to_ary
  end

  def active_time_entries_with_day_order_and_effective_dates_sql
    " SELECT t.start_time, t.end_time, p.order, r.effective_at, r.effective_till
      FROM time_entries AS t
        INNER JOIN  presence_days AS p
          ON t.presence_day_id = p.id
          INNER JOIN (#{active_employee_presence_policies_for_range_query}) AS r
            ON p.presence_policy_id = r.presence_policy_id;
    "
  end

  def active_employee_presence_policies_for_range_query
    JoinTableWithEffectiveTill
      .new(EmployeePresencePolicy, employee.account, nil, employee.id, nil, start_date, end_date)
      .sql
  end
end
