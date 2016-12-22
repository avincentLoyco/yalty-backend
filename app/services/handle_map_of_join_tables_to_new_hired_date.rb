class HandleMapOfJoinTablesToNewHiredDate
  attr_reader :employee, :new_hired_date, :join_table_class, :balances, :join_tables_in_range

  JOIN_TABLES_CLASSES = %w(employee_working_places
                           employee_presence_policies
                           employee_time_off_policies).freeze

  def initialize(employee, new_hired_date)
    @employee = employee
    @new_hired_date = new_hired_date
    @balances = []
  end

  def call
    return {} if new_hired_date == employee.hired_date
    { join_tables: updated_join_tables, employee_balances: balances }
  end

  private

  def updated_join_tables
    JOIN_TABLES_CLASSES.map do |join_table_class|
      @join_table_class = join_table_class
      @join_tables_in_range = find_join_tables_in_range
      if new_hired_date < employee.hired_date
        update_join_table_at_hired_date
      else
        update_or_remove_join_table
      end
    end.compact.flatten.uniq
  end

  def single_etop_by_category_in_range?
    employee_time_off_policy? &&
      grouped_etops_in_range.map do |_category, etop_collection|
        etop_collection.size
      end.uniq.eql?([1])
  end

  def update_join_table_at_hired_date
    join_tables_at_hired_date =
      if employee_time_off_policy?
        join_tables_in_range
      else
        [join_tables_in_range.last]
      end

    return unless join_tables_at_hired_date.present?
    join_tables_at_hired_date.compact.map do |join_table|
      update_time_off_policy_assignation_balance(join_table) if employee_time_off_policy?
      join_table.tap { |table| table.assign_attributes(effective_at: new_hired_date) }
    end
  end

  def update_or_remove_join_table
    if join_tables_in_range.size < 2 || single_etop_by_category_in_range?
      update_join_table_at_hired_date
    else
      return remove_older_join_tables_and_update_last unless employee_time_off_policy?
      remove_and_update_etops_by_category
    end
  end

  def remove_and_update_etops_by_category
    grouped_etops_in_range.map do |_category, etop_collection|
      join_tables_to_destroy = etop_collection.first(etop_collection.size - 1)
      join_tables_to_destroy.map(&:policy_assignation_balance).compact.map(&:destroy!)
      join_tables_to_destroy.map(&:destroy!)
      update_time_off_policy_assignation_balance(etop_collection.last)
      etop_collection.last.tap { |etop| etop.assign_attributes(effective_at: new_hired_date) }
    end
  end

  def remove_older_join_tables_and_update_last(join_tables = join_tables_in_range)
    join_tables_to_destroy_size = join_tables.size - 1
    join_tables.limit(join_tables_to_destroy_size).destroy_all
    join_tables.last.tap do |join_table|
      join_table.assign_attributes(effective_at: new_hired_date)
    end
  end

  def update_time_off_policy_assignation_balance(etop)
    assignation_balance = etop.policy_assignation_balance
    return unless assignation_balance.present?
    validity_date = RelatedPolicyPeriod.new(etop).validity_date_for(new_hired_date)
    assignation_balance.assign_attributes(
      effective_at: new_hired_date + Employee::Balance::START_DATE_OR_ASSIGNATION_OFFSET,
      policy_credit_addition: time_off_policy_start_date?(etop),
      validity_date: validity_date
    )
    balances.push(assignation_balance)
  end

  def find_join_tables_in_range
    dates = [employee.hired_date, new_hired_date]
    employee
      .send(join_table_class)
      .where(effective_at: dates.min..dates.max)
      .order(:effective_at)
  end

  def grouped_etops_in_range
    join_tables_in_range.group_by { |table| table[:time_off_category_id] }
  end

  def employee_time_off_policy?
    join_table_class.eql?('employee_time_off_policies')
  end

  def time_off_policy_start_date?(etop)
    policy = etop.time_off_policy
    new_hired_date.to_date == Date.new(new_hired_date.year, policy.start_month, policy.start_day)
  end
end