class TimeEntriesForEmployeeSchedule
  def initialize(employee, start_date, end_date)
    @employee = employee
    @start_date = start_date
    @end_date = end_date
    @time_entries_hash = {}
  end

  def call
    create_time_entries_hash_structure
    fetch_and_process
    @time_entries_hash
  end

  private

  def create_time_entries_hash_structure
    calculate_time_range(@start_date, @end_date).times do |i|
      date = (@start_date + i.days)
      @time_entries_hash[date.to_s] = []
    end
  end

  def fill_pp_info_hash(query_hash)
    start_date = start_date_for_epp(query_hash)
    end_date = query_hash['effective_till'].present? ? end_date_for_epp(query_hash) : @end_date
    {
      'start_date' => start_date,
      'end_date' => end_date,
      'start_order' => order_for(start_date, query_hash),
      'range_size' => calculate_time_range(start_date, end_date),
      'policy_length' => query_hash['max_order'].to_i
    }
  end

  def order_for(date, query_hash)
    effective_at_date = query_hash['effective_at'].to_date
    policy_length = query_hash['max_order'].to_i
    start_day_order = query_hash['order_of_start_day'].to_i

    return start_day_order if date == effective_at_date
    order_difference = ((date - effective_at_date) % policy_length).to_i
    new_order = start_day_order + order_difference
    new_order > policy_length ? new_order - policy_length : new_order
  end

  def start_date_for_epp(query_hash)
    effective_at = query_hash['effective_at'].to_date
    effective_at >= @start_date ? effective_at : @start_date
  end

  def end_date_for_epp(query_hash)
    effective_till = query_hash['effective_till'].to_date
    effective_till <= @end_date ? effective_till : @end_date
  end

  def calculate_time_range(start_date, end_date)
    (end_date - start_date).to_i + 1
  end

  def fetch_and_process
    pp_info_hash = {}
    fetch_usefull_info.each do |query_hash|
      presence_policy_id = query_hash['presence_policy_id']
      pp_info_hash[presence_policy_id] ||= fill_pp_info_hash(query_hash)
      presence_policy_hash = pp_info_hash[presence_policy_id]
      order_count = calculate_ocurrences_of_time_entry(
        query_hash['order'].to_i,
        presence_policy_hash
      )
      fill_time_entries_hash(query_hash, order_count, presence_policy_hash)
    end
  end

  def fill_time_entries_hash(query_hash, order_count, pp_info_hash)
    offset = calculate_order_offset_from_start_day_order(
      pp_info_hash['start_order'],
      query_hash['order'].to_i,
      query_hash['max_order'].to_i
    )
    order_count.times do |i|
      date = (pp_info_hash['start_date'] + (offset + (i * pp_info_hash['policy_length'])).days)
      next if date > pp_info_hash['end_date']
      @time_entries_hash[date.to_s] << create_time_entry_hash(query_hash)
    end
  end

  def create_time_entry_hash(query_hash)
    {
      type: 'working_time',
      start_time: query_hash['start_time'],
      end_time: query_hash['end_time']
    }
  end

  def calculate_order_offset_from_start_day_order(start_day_order, order, policy_length)
    start_day_order <= order ? order - start_day_order : policy_length - start_day_order + order
  end

  def calculate_ocurrences_of_time_entry(order, epp_hash)
    start_order = epp_hash['start_order']
    policy_length = epp_hash['policy_length']
    end_order = ((epp_hash['range_size'] % policy_length) + start_order - 1) % policy_length
    order_count = epp_hash['range_size'] / policy_length
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
             r.presence_policy_id, r.order_of_start_day, p.max_order
      FROM time_entries AS t
        INNER JOIN (
          SELECT presence_days.*, p_with_max_order.max_order as max_order
            FROM presence_days
            INNER JOIN (
              SELECT p_max.presence_policy_id, max(p_max.order) as max_order
              FROM presence_days as p_max
              GROUP BY p_max.presence_policy_id
            ) as p_with_max_order
            ON presence_days.presence_policy_id = p_with_max_order.presence_policy_id
           ) as p
          ON t.presence_day_id = p.id
          INNER JOIN (#{active_employee_presence_policies_for_range_query}) AS r
            ON p.presence_policy_id = r.presence_policy_id;
    "
  end

  def active_employee_presence_policies_for_range_query
    JoinTableWithEffectiveTill
      .new(EmployeePresencePolicy,
        @employee.account_id,
        nil,
        @employee.id,
        nil,
        @start_date,
        @end_date)
      .sql('', '')
      .tr(';', '')
  end
end
