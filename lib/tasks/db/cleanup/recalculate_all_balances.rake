namespace :db do
  namespace :cleanup do
    desc 'Recalcualtes the balances for every employee'
    task recalculate_all_balances: [:environment] do
      puts 'Update balances and being processed flag'
      puts
      employees_with_balances.find_each do |employee|
        grouped_balances(employee).each do |_category, balances|
          PrepareEmployeeBalancesToUpdate.new(balances.first, update_all: true).call
          UpdateBalanceJob.perform_later(balances.first.id, update_all: true)
        end
      end
      puts 'Finished processing balances'
      puts
    end
  end

  def grouped_balances(employee)
    employee.employee_balances.order(:effective_at).group_by do |balance|
      balance[:time_off_category_id]
    end
  end

  def employees_with_balances
    Employee.joins(:employee_balances).where('employee_balances.id is not null')
  end
end
