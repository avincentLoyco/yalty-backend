namespace :maintainance do
  desc 'Create missing balances, and recalculate every balance for every employee'
  task create_missing_and_update_all_balances: [:environment] do
    ActiveRecord::Base.transaction do
      puts 'Creating Missing balances'
      puts
      Rake::Task[:create_missing_balances].invoke
      puts 'Recalculating every employee balance'
      puts
      Rake::Task[:recalculate_all_balances].invoke
      puts
      puts 'END'
    end
  end
end
