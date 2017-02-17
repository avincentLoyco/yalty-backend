namespace :attribute_definitions do
  desc 'Creates missing attribute definitions for account'

  task update: :environment do
    puts 'Removing unused attribute definitions'
    Rake::Task['attribute_definitions:remove_not_used'].invoke

    puts 'Creating new definitions'
    Rake::Task['attribute_definitions:create_missing'].invoke
  end

  task remove_not_used: :environment do
    ids_to_remove = Employee::AttributeDefinition.where(name: definitions_to_remove).pluck(:id)
    Employee::AttributeVersion.where(attribute_definition_id: ids_to_remove).destroy_all
    Employee::AttributeDefinition.where(id: ids_to_remove).destroy_all
  end

  task create_missing: :environment do
    Account.all.each do |account|
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
