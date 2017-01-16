namespace :attribute_definitions do
  desc 'Creates missing attribute definitions for account'
  task create_missing: :environment do
    Account.all.each do |account|
      account.update_default_attribute_definitions! unless all_attribute_definitions?(account)
    end
  end

  def all_attribute_definitions?(account)
    account.employee_attribute_definitions
           .where(system: true)
           .count('DISTINCT attribute_type')
           .eql?(Account::DEFAULT_ATTRIBUTES.count)
  end
end
