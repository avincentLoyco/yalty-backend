namespace :split_time_offs do
  task between_or_migration_date: :environment do
    time_offs = TimeOff.where('start_time <= ? AND end_time > ?',
                              Time.zone.local(2017, 12, 31, 23, 59, 59),
                              Time.zone.local(2018, 1, 1, 0, 0)).vacations

    time_offs.each do |time_off|
      split_time_off(time_off)
    end
  end

  def split_time_off(time_off)
    end_time = time_off.end_time.to_s

    update_first_time_off(time_off)
    create_second_time_off(time_off, end_time)
  end

  def update_first_time_off(time_off)
    utc_end_time = Time.new(2017, 12, 31, 23, 59, 59, '+00:00').to_s
    balance_attr = balance_attributes(time_off)

    ActiveRecord::Base.transaction do
      time_off.update!(end_time: utc_end_time)
      PrepareEmployeeBalancesToUpdate.new(time_off.employee_balance, balance_attr).call
    end
    UpdateBalanceJob.perform_now(time_off.employee_balance.id, balance_attr)
  end

  def create_second_time_off(prev_time_off, end_time)
    resource = TimeOff.new(time_off_attributes(prev_time_off, end_time))
    ActiveRecord::Base.transaction do
      resource.save! && create_new_employee_balance(resource)
    end
  end

  def time_off_attributes(time_off, end_time)
    start_time = Time.new(2018, 1, 1, 0, 0, 0, '+00:00').to_s
    {
      start_time: start_time,
      end_time: end_time,
      time_off_category: time_off.time_off_category,
      employee: time_off.employee
    }
  end

  def balance_attributes(time_off)
    {
      manual_amount: 0,
      resource_amount: time_off.balance,
      effective_at: time_off.start_time.to_s
    }
  end

  def create_new_employee_balance(resource)
    CreateEmployeeBalance.new(
      resource.time_off_category_id,
      resource.employee_id,
      resource.employee.account.id,
      time_off_id: resource.id,
      balance_type: 'time_off',
      resource_amount: resource.balance,
      manual_amount: 0,
      effective_at: resource.end_time
    ).call
  end
end
