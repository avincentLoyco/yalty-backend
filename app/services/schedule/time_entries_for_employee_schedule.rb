class TimeEntriesForEmployeeSchedule
  attr_reader :employee, :start_date, :end_date, :time_entries_hash

  def initialize(employee, start_date, end_date)
    @employee = employee
    @start_date = start_date
    @end_date = end_date
    @time_entries_hash = {}
  end

  def call
    fill_time_entries_hash
  end

  private

  def fill_pp_info_hash(query_hash)
    start_date = query_hash[:effective_at].to_date
    end_date = query_hash[:effective_till].to_date
    {
      effective_at: query_hash[:effective_at],
      effective_till: query_hash[:effective_till],
      start_order: start_date.wday.to_s.sub('0', '7').to_i,
      range_size:
        calculate_time_range(start_date, end_date)

    }

  end

  def calculate_time_range(start_date, end_date)
    (end_date - start_date).to_i + 1
  end

  def fill_time_entries_hash
    pp_info_hash = {}
    fetch_usefull_info.each do |query_hash|
      presence_policy_id = query_hash[:presence_policy_id]
      pp_info_hash[presence_policy_id] ||= fill_pp_info_hash.key?(query_hash)
      order_count = calculate_ocurrences(query_hash[:order], pp_info_hash[presence_policy_id])
      # TODO
    end
  end

  def calculate_ocurrences_of_time_entry(order, epp_hash)
    start_order = epp_hash[:start_order]
    end_order = ((epp_hash[:range_size] % 7) + start_order - 1) % 7
    order_count = range_size / 7
    if start_order >= end_order && (order >= start_order || order <= end_order)
      order_count += 1
    elsif start_order < end_order && order <= end_order && order >= start_order
      order_count += 1
    end
    order_count
  end

  def fetch_usefull_info
    ActiveRecord::Base.connection.select_all(
      active_time_entries_with_day_order_and_effective_dates_sql
    ).to_ary
  end

  def active_time_entries_with_day_order_and_effective_dates_sql
    " SELECT t.start_time, t.end_time, p.order, r.effective_at, r.effective_till,
             r.presence_policy_id
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
