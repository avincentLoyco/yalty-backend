class HandleContractEnd
  JOIN_TABLES =
    %w(employee_time_off_policies employee_presence_policies employee_working_places).freeze

  def initialize(employee, contract_end_date)
    @employee = employee
    @contract_end_date = contract_end_date
    @account = employee.account
    @next_hire_date = find_next_hire_date(employee)
  end

  def call
    ActiveRecord::Base.transaction do
      remove_join_tables
      remove_time_offs
      remove_balances
      assign_reset_resources
      move_time_offs
      assign_reset_balances
    end
  end

  private

  def remove_join_tables
    join_tables = JOIN_TABLES.map do |table_name|
      @employee.send(table_name).where('effective_at > ?', @contract_end_date)
    end
    return join_tables.map(&:delete_all) unless @next_hire_date.present?
    join_tables.map { |table| table.where('effective_at < ?', @next_hire_date).delete_all }
  end

  def remove_time_offs
    time_offs.each do |time_off|
      time_off.employee_balance.destroy
      time_off.destroy
    end
  end

  def time_offs
    time_offs = @employee.time_offs.where('start_time > ?', @contract_end_date)
    return time_offs unless @next_hire_date.present?
    time_offs.where('start_time < ?', @next_hire_date)
  end

  def remove_balances
    @employee
      .employee_balances
      .where('effective_at > ?', @contract_end_date + 1.day)
      .not_time_off.delete_all
  end

  def assign_reset_resources
    @reset_join_tables =
      %w(presence_policies working_places time_off_policies).map do |resources_name|
        AssignResetJoinTable.new(resources_name, @employee, nil, @contract_end_date).call
      end
  end

  def assign_reset_balances
    employee_time_off_policies =
      @reset_join_tables.flatten.select { |table| table.class.eql?(EmployeeTimeOffPolicy) }
    return unless employee_time_off_policies.present?
    employee_time_off_policies.map do |etop|
      AssignResetEmployeeBalance.new(etop).call
    end
  end

  def move_time_offs
    @employee.time_offs.where(''"
      start_time < '#{@contract_end_date}'::timestamp AND
      end_time > '#{@contract_end_date}'::timestamp
    "'').map do |time_off|
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
      .where(event_type: 'hired').where('effective_at > ?', @contract_end_date)
      .order(:effective_at).first.try(:effective_at)
  end
end
