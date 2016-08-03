class AddRegisteredWorkingTimes < ActiveJob::Base
  queue_as :registered_working_times

  def perform
    @today = Time.zone.today - 1

    employees_with_working_hours_ids =
      Employee
      .joins(:registered_working_times)
      .where(registered_working_times: { date: @today })
      .pluck(:id)
    all_employees_ids = Employee.where.not(id: employees_with_working_hours_ids).pluck(:id)
    employees_ids_with_holidays = find_employees_ids_with_holidays(all_employees_ids)
    employees_ids_without_holidays = all_employees_ids - employees_ids_with_holidays
    CreateRegisteredWorkingTime.new(@today, employees_ids_without_holidays).call
    CreateRegisteredWorkingTime.new(@today, employees_ids_with_holidays, true).call
  end

  private

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
