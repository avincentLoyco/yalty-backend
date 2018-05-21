namespace :db do
  namespace :cleanup do
    desc "Remove duplicated join tables, update balances if any affected"

    task remove_duplicated_join_tables: :environment do
      join_tables_with_resources = [
        [EmployeeWorkingPlace, "working_place_id"],
        [EmployeePresencePolicy, "presence_policy_id"],
        [EmployeeTimeOffPolicy, "time_off_policy_id"],
      ]

      join_tables_to_delete = join_tables_with_resources.map do |join_table_class, resource_class|
        possible_repeated_joins_tables = find_join_tables_to_verify(join_table_class)
        find_duplicated_join_tables(possible_repeated_joins_tables, resource_class)
      end.flatten.compact

      remove_and_update_balances(join_tables_to_delete)
      join_tables_to_delete.map(&:destroy!)
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
      join_tables.values.map do |join_tables_in_category|
        join_tables_in_category.map.each_with_index do |jt, index|
          next_jt = join_tables_in_category[index + 1]
          next_jt if next_jt && jt.send(resource_class_id) == next_jt.send(resource_class_id)
        end
      end
    end

    def remove_and_update_balances(join_tables_to_delete)
      join_tables_to_delete.select { |jt| jt.class.eql?(EmployeeTimeOffPolicy) }.each do |jt|
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
end
