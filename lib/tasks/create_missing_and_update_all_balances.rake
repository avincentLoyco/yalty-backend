task create_missing_and_update_all_balances: [:environment] do
  puts 'Creating Missing balances'
  puts ''
  Rake::Task[:create_missing_balances].invoke
  puts 'Recalculating every employee balance'
  puts ''
  Rake::Task[:recalculate_all_balances].invoke
  puts ''
  puts 'END'
end
