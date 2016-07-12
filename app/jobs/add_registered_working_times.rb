class AddRegisteredWorkingTimes < ActiveJob::Base
  queue_as :registered_working_times

  def perform
    fetch_and_process
  end

  private

  def fetch_and_process
    @today = Time.zone.today - 1
    employees_with_working_hours_ids =
      Employee
        .joins(:registered_working_times)
        .where( registered_working_times: { date: @today })
        .pluck(:id)
    employees_ids = Employee.where.not(id: employees_with_working_hours_ids).pluck(:id)
    process_employees(employees_ids)
  end


  def process_employees(employees_ids)
    time_offs_time_entries =
      TimeOffForEmployeeSchedule.new(employees_ids, @today, @today).call
    employees_time_entries = active_time_entries_per_employee(employees_ids)
    employees_splitted_entries =
      SplitTimeEntriesByTimeEntriesAndEmployeesForDate.new(
        employees_time_entries,
        time_offs_time_entries[@today.to_s],
        '',
        true
      ).call
    insert_employees_registered_working_times(employees_splitted_entries)
  end

  def active_time_entries_per_employee(employees_ids)
    ActiveRecord::Base.connection.select_all(
      active_time_entries_with_day_order_and_effective_dates_sql(employees_ids)
    ).to_ary
  end
  # For the future instead of ((( to_date('#{today}', 'YYYY-MM_DD') - r.effective_at  ) % 7)
  # replace the 7 with
  # replace (INNER JOIN  presence_days AS p)  with
  # INNER JOIN (
  #   SELECT presence_days.*, p_with_max_order.max_order as max_order
  #     FROM presence_days
  #     INNER JOIN (
  #       SELECT p_max.presence_policy_id, max(p_max.order) as max_order
  #       FROM presence_days as p_max
  #       GROUP BY p_max.presence_policy_id;
  #     ) as p_with_max_order
  #     ON presence_days.presence_policy_id = p_with_max_order.presence_policy_id
  # ) as p
  #
  # and then replace the 7 in ((( to_date('#{today}', 'YYYY-MM_DD') - r.effective_at  ) % 7)
  # with p.max_order
  #
  #
  # This returns Only the time entries of a person that belong to what today will be their day order
  #
  def active_time_entries_with_day_order_and_effective_dates_sql(employees_ids)
    " SELECT t.start_time, t.end_time, r.employee_id
      FROM time_entries AS t
        INNER JOIN  presence_days AS p
          ON t.presence_day_id = p.id
          INNER JOIN (#{active_employee_presence_policies_for_range_query_sql(employees_ids)}) AS r
            ON p.presence_policy_id = r.presence_policy_id
      WHERE p.order = ((( to_date('#{@today}', 'YYYY-MM_DD') - r.effective_at  ) % 7) + 1);
    "
  end

  def active_employee_presence_policies_for_range_query_sql(employees_ids)
    JoinTableWithEffectiveTill
      .new(EmployeePresencePolicy,
        nil,
        nil,
        employees_ids,
        nil,
        @today,
        @today)
      .sql('', '')
      .tr(';', '')
  end

  def insert_employees_registered_working_times(time_entries_employee_hash)
    time_entries_employee_hash.each do |employee_id, time_entries_array |
      RegisteredWorkingTime.create(
        employee_id: employee_id,
        schedule_generated: true,
        date: @today,
        time_entries: time_entries_array
      )
    end
  end
end
