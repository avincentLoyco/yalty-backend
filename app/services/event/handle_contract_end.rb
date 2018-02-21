class HandleContractEnd
  def initialize(employee, contract_end_date, old_contract_end = nil)
    @employee = employee
    @contract_end_date = contract_end_date
    @account = employee.account
    @next_hire_date = find_next_hire_date(employee)
    @old_contract_end = old_contract_end
  end

  def call
    ActiveRecord::Base.transaction do
      remove_join_tables
      remove_time_offs
      remove_balances
      assign_reset_resources
      move_time_offs
      assign_reset_balances_and_create_additions
    end
  end

  private

  def remove_join_tables
    join_tables = Employee::RESOURCE_JOIN_TABLES.map do |table_name|
      @employee.send(table_name).where("effective_at > ?", @contract_end_date)
    end
    return join_tables.map(&:delete_all) if @next_hire_date.nil?
    join_tables.map do |table|
      if @contract_end_date.eql?(@old_contract_end)
        table.where("effective_at < ?", @next_hire_date).not_reset.delete_all
      else
        table.where("effective_at < ?", @next_hire_date).delete_all
      end
    end
  end

  def remove_time_offs
    time_offs.each do |time_off|
      time_off.employee_balance.destroy
      time_off.destroy
    end
  end

  def time_offs
    time_offs = @employee.time_offs.where("start_time > ?", @contract_end_date.end_of_day)
    return time_offs unless @next_hire_date.present?
    time_offs.where("start_time < ?", @next_hire_date)
  end

  def remove_balances
    balances_after =
      @employee
      .employee_balances
      .not_time_off.where("effective_at > ?", @contract_end_date + 1.day + 2.seconds)
    return balances_after.delete_all unless @next_hire_date.present?
    balances_after.where("effective_at < ?", @next_hire_date).delete_all
  end

  def assign_reset_resources
    @join_tables =
      %w(presence_policies working_places time_off_policies).map do |resources_name|
        AssignResetJoinTable.new(resources_name, @employee, nil, @contract_end_date).call
      end
  end

  def assign_reset_balances_and_create_additions
    @employee.employee_time_off_policies.pluck(:time_off_category_id).uniq.map do |category_id|
      AssignResetEmployeeBalance.new(
        @employee, category_id, @contract_end_date, @old_contract_end
      ).call
      next unless @old_contract_end && @contract_end_date > @old_contract_end
      etop = @employee.active_policy_in_category_at_date(category_id, @old_contract_end)
      ManageEmployeeBalanceAdditions.new(etop).call
    end
  end

  def move_time_offs
    @employee.time_offs.where("""
      start_time <= '#{@contract_end_date.end_of_day}'::timestamp AND
      end_time > '#{@contract_end_date + 1.day}'::timestamp
    """).map do |time_off|
      time_off.update!(end_time: @contract_end_date + 1.day)
      validity_date = time_off.employee_balance.validity_date
      time_off.employee_balance.update!(
        effective_at: time_off.end_time, validity_date: validity_date
      )
    end
  end

  def find_next_hire_date(employee)
    employee
      .events
      .hired.where("effective_at > ?", @contract_end_date)
      .order(:effective_at).first.try(:effective_at)
  end
end
