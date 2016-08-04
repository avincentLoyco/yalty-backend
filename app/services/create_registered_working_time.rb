class CreateRegisteredWorkingTime
  def initialize(today, employees_ids = [])
    @today = today
    @employees_ids = employees_ids
  end

  def call
    process_employees(@employees_ids - employees_with_working_hours_ids)
  end

  private

  def employees_with_working_hours_ids
    Employee
      .joins(:registered_working_times)
      .where(registered_working_times: { date: @today })
      .pluck(:id)
  end

  def process_employees(employees_ids)
    employees_splitted_entries = {}

    employees_ids_without_holidays = employees_ids - find_employees_ids_with_holidays(employees_ids)
    if employees_ids_without_holidays.any?
      time_offs_time_entries =
        TimeOffForEmployeeSchedule.new(employees_ids_without_holidays, @today, @today).call
      employees_time_entries = active_time_entries_per_employee(employees_ids_without_holidays)
      employees_splitted_entries =
        SplitTimeEntriesByTimeEntriesAndEmployeesForDate.new(
          employees_time_entries,
          time_offs_time_entries[@today.to_s],
          '',
          true
        ).call
    end
    insert_employees_registered_working_times(employees_splitted_entries, employees_ids)
  end

  def insert_employees_registered_working_times(time_entries_employee_hash, employees_ids)
    employees_ids.each do |employee_id|
      time_entries_array = time_entries_employee_hash.with_indifferent_access[employee_id]
      time_entries_array ||= []
      RegisteredWorkingTime.create(
        employee_id: employee_id,
        schedule_generated: true,
        date: @today,
        time_entries: time_entries_array
      )
    end
  end

  def active_time_entries_per_employee(employees_ids)
    ActiveRecord::Base.connection.select_all(
      active_time_entries_with_day_order_and_effective_dates_sql(employees_ids)
    ).to_ary
  end

  def active_time_entries_with_day_order_and_effective_dates_sql(employees_ids)
    " SELECT t.start_time, t.end_time, r.employee_id
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
          INNER JOIN (#{active_employee_presence_policies_for_range_query_sql(employees_ids)}) AS r
            ON p.presence_policy_id = r.presence_policy_id
      WHERE (p.order % p.max_order)  = (
        (r.order_of_start_day + (to_date('#{@today}', 'YYYY-MM-DD') - r.effective_at)) % p.max_order
      );
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

  def find_employees_ids_with_holidays(employees_ids)
    countries_and_regions_with_holidays_hash =
      regions_per_country_with_holiday_today_and_active_policy

    holiday_policies_ids = []
    countries_and_regions_with_holidays_hash.each do |country, regions|
      search_options = { country: country }
      search_options[:region] = regions if regions.any?
      holiday_policies_ids += HolidayPolicy.where(search_options).pluck(:id)
    end
    holiday_policies_ids.any? ? employees_ids_with_holiday(employees_ids, holiday_policies_ids) : []
  end

  def regions_per_country_with_holiday_today_and_active_policy
    countries = HolidayPolicy.all.pluck(:country).uniq
    countries_and_regions_hash = {}
    countries.each do |country|
      countries_and_regions_hash[country.to_sym] = []
      holiday_today = Holidays.between(@today, @today, "#{country}_".to_sym).first
      country_plus_regions = holiday_today.present? ? holiday_today[:regions] : []
      country_plus_regions.each do |country_plus_region|
        countries_and_regions_hash[country.to_sym] << country_plus_region.to_s.split('_').last
      end
      countries_and_regions_hash[country.to_sym].compact!
    end
    countries_and_regions_hash
  end

  def employees_with_holiday_today(employees_ids, holiday_policies_ids)
    ActiveRecord::Base.connection.select_all(
      employees_with_holiday_policy_active_today_sql(
        employees_ids,
        holiday_policies_ids
      )
    ).to_ary
  end

  def employees_ids_with_holiday(employees_ids, holiday_policies_ids)
    employees_with_holiday_today(employees_ids, holiday_policies_ids).map do |employee_id_hash|
      employee_id_hash['id']
    end
  end

  def convert_array_to_sql(array)
    "('#{array.join('\',\'')}')"
  end

  def employees_with_holiday_policy_active_today_sql(employees_ids, holiday_policies_ids)
    " SELECT employees.id
      FROM employees
      INNER JOIN (#{active_employee_working_places_for_range_query_sql(employees_ids)}) AS ewp
        ON employees.id = ewp.employee_id
        INNER JOIN working_places
          ON ewp.working_place_id = working_places.id
      WHERE working_places.holiday_policy_id IN #{convert_array_to_sql(holiday_policies_ids)} ;
    "
  end

  def active_employee_working_places_for_range_query_sql(employees_ids)
    JoinTableWithEffectiveTill
      .new(EmployeeWorkingPlace,
        nil,
        nil,
        employees_ids,
        nil,
        @today,
        @today)
      .sql('', '')
      .tr(';', '')
  end
end
