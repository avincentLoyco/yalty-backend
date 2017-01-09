desc 'Recalcualtes the balances for every employee'
task recalculate_all_balances: [:environment] do
  ActiveRecord::Base.connection_pool.with_connection do
    initial_etop_balances = Employee::Balance.all.order(:effective_at)
    puts 'Updating the being_processed flag of all balances'
    puts
    initial_etop_balances.update_all(being_processed: true)

    puts 'Updating the balances'
    puts
    initial_etop_balances.each do |balance|
      begin
        UpdateEmployeeBalance.new(balance).call
      rescue
        puts "Employee Balance with an issue is  #{balance.id} "
      end
    end
    puts 'Finished processing balances'
    puts
  end
end
