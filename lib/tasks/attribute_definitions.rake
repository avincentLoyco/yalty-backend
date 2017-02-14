namespace :attribute_definitions do
  desc 'Creates missing attribute definitions for account'
  task create_missing: :environment do
    Account.all.each do |account|
      account.employee_attribute_definitions.where(name: definitions_to_remove).destroy_all
      account.update_default_attribute_definitions! unless all_attribute_definitions?(account)
    end
  end

  def all_attribute_definitions?(account)
    account.employee_attribute_definitions
           .where(system: true)
           .count
           .eql?(Account::DEFAULT_ATTRIBUTES.values.flatten.uniq.count)
  end

  def definitions_to_remove
    %w(number_of_months child_is_student start_date civil_status civil_status_date)
  end
end
