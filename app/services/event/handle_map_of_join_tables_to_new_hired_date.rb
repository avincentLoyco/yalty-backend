class HandleMapOfJoinTablesToNewHiredDate
  attr_reader :employee, :new_hired_date, :join_table_class, :balances, :join_tables_in_range,
    :old_hired_date

  JOIN_TABLES_CLASSES = %w(employee_working_places
                           employee_presence_policies
                           employee_time_off_policies).freeze

  def initialize(employee, new_hired_date, old_hired_date)
    @employee = employee
    @new_hired_date = new_hired_date
    @old_hired_date = old_hired_date
    @balances = []
  end

  def call
    return {} if new_hired_date.eql?(old_hired_date) || contract_end_between?
    { join_tables: updated_join_tables, employee_balances: balances }
  end

  private

  def contract_end_between?
    return false unless employee && new_hired_date > old_hired_date
    employee
      .events
      .where('effective_at > ? AND effective_at <= ?', old_hired_date, new_hired_date)
      .pluck(:event_type)
      .include?('contract_end')
  end

  def updated_join_tables
    JOIN_TABLES_CLASSES.map do |join_table_class|
      @join_table_class = join_table_class
      @join_tables_in_range = find_join_tables_in_range
      if new_hired_date < old_hired_date
        update_join_table_at_hired_date
      else
        update_or_remove_join_table
      end
    end.flatten.compact.uniq
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
      next if join_table.related_resource.reset?
      remove_reset_join_table(join_table) if contract_end_before?
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

  def remove_reset_join_table(join_table)
    reset_join_table_at_date =
      join_table.class.with_reset.where(effective_at: new_hired_date, employee: employee)

    if join_table.class.eql?(EmployeeTimeOffPolicy)
      reset_join_table_at_date.where(time_off_category_id: join_table.time_off_category_id).first
    else
      reset_join_table_at_date.first
    end.try(:destroy!)
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
    remove_employee_balances_between_hired_dates(assignation_balance, etop)
    existing_balance = balance_at_new_hired(etop)
    updated_balance =
      if existing_balance
        update_existing_balance(etop, existing_balance, assignation_balance)
      else
        assign_attributes_to_assignation(etop, assignation_balance)
      end
    balances.push(updated_balance)
  end

  def remove_employee_balances_between_hired_dates(assignation, etop)
    return unless new_hired_date > old_hired_date
    balances_to_remove =
      employee
      .employee_balances
      .in_category(assignation.time_off_category_id)
      .where.not(id: [assignation.id, balance_at_new_hired(etop)])
      .where(time_off_id: nil)
      .where(
        'effective_at BETWEEN ? AND ?',
        old_hired_date, new_hired_date + Employee::Balance::REMOVAL_OFFSET
      )
    removals = balances_to_remove.map(&:balance_credit_removal).compact
    balances_to_remove.destroy_all
    destroy_removals!(removals) if removals. present?
  end

  def destroy_removals!(removals)
    removals.map do |removal|
      removal.destroy! if removal.balance_credit_additions.blank?
    end
  end

  def find_join_tables_in_range
    dates = [old_hired_date, new_hired_date]
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

  def balance_at_new_hired(etop)
    employee
      .employee_balances
      .where(
        time_off_category_id: etop.time_off_category_id,
        effective_at: new_hired_date + Employee::Balance::ASSIGNATION_OFFSET
      )
      .first
  end

  def update_existing_balance(etop, existing_balance, assignation_balance)
    existing_balance.manual_amount = assignation_balance.manual_amount
    existing_balance.validity_date = RelatedPolicyPeriod.new(etop).validity_date_for(new_hired_date)
    assignation_balance.destroy!
    existing_balance
  end

  def assign_attributes_to_assignation(etop, assignation_balance)
    assignation_balance.tap do |balance|
      validity_date =
        RelatedPolicyPeriod.new(etop).validity_date_for_balance_at(new_hired_date, 'assignation')
      balance.assign_attributes(
        effective_at: new_hired_date + Employee::Balance::ASSIGNATION_OFFSET,
        balance_type: 'assignation',
        validity_date: validity_date,
        resource_amount: 0
      )
    end
  end

  def contract_end_before?
    @contract_end_before ||=
      employee
      .events
      .where(effective_at: new_hired_date - 1.day, event_type: 'contract_end')
      .present?
  end
end
