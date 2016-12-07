namespace :attribute_definitions do
  desc 'Creates missing attribute definitions for account'
  task create_missing: :environment do
    Account.all.map(&:update_default_attribute_definitions!)
  end
end
