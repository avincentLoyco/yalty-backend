namespace :db do
  namespace :cleanup do
    desc 'Create missing balances, and recalculate every balance for every employee'
    task create_missing_and_update_all_balances: [:environment] do
      ActiveRecord::Base.transaction do
        puts 'Creating Missing balances'
        puts
        Rake::Task['db:cleanup:create_missing_balances'].invoke
        puts 'Create Missing TimeOff Balances'
        puts
        Rake::Task['db:cleanup:create_missing_balances_and_policies_for_time_offs'].invoke
        puts 'Recalculating every employee balance'
        puts
        Rake::Task['db:cleanup:recalculate_all_balances'].invoke
        puts
        puts 'END'
      end
    end
  end
end
