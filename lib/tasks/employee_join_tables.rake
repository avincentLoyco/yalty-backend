namespace :employee_join_tables do
  desc 'Remove duplicated join tables, update balances if any affected'
  task remove_duplicated: :environment do
    @join_tables_to_delete = []

    join_tables_with_resources = [
      [EmployeeWorkingPlace, 'working_place_id'],
      [EmployeePresencePolicy, 'presence_policy_id'],
      [EmployeeTimeOffPolicy, 'time_off_policy_id']
    ]

    join_tables_with_resources.each do |join_table_class, resource_class|
      to_verify = find_join_tables_to_verify(join_table_class)
      find_duplicated_join_tables(to_verify, resource_class)
    end

    remove_and_update_balances
    @join_tables_to_delete.map(&:destroy!)
  end

  def find_join_tables_to_verify(join_table_class)
    if join_table_class.eql?(EmployeeTimeOffPolicy)
      join_table_class
        .order(:effective_at)
        .group_by { |etop| [etop[:time_off_category_id], etop[:employee_id]] }
    else
      join_table_class.order(:effective_at).group_by { |jt| jt[:employee_id] }
    end.select { |_k, v| v.size > 1 }
  end

  def find_duplicated_join_tables(join_tables, resource_class_id)
    join_tables.values.each do |join_tables_in_category|
      join_tables_in_category.each_with_index do |jt, index|
        next if join_tables_in_category[index + 1].nil?
        if jt.send(resource_class_id) == join_tables_in_category[index + 1].send(resource_class_id)
          @join_tables_to_delete << join_tables_in_category[index + 1]
        end
      end
    end
  end

  def remove_and_update_balances
    @join_tables_to_delete.select { |jt| jt.class.eql?(EmployeeTimeOffPolicy) }.each do |jt|
      assignation_balance = jt.policy_assignation_balance
      next unless assignation_balance
      next_balance_id = RelativeEmployeeBalancesFinder.new(assignation_balance).next_balance
      if next_balance_id
        next_balance = Employee::Balance.find(next_balance_id)
        PrepareEmployeeBalancesToUpdate.new(next_balance).call
        UpdateBalanceJob.perform_later(next_balance)
      end
      assignation_balance.destroy!
    end
  end
end
