namespace :attribute_definitions do
  desc "Creates missing attribute definitions, updates their validations, remove the unused ones."

  MARRIAGE_STATUSES = %w(Marié Mariée).freeze

  task update: :environment do
    puts "Remove unused attribute definitions"
    Rake::Task["attribute_definitions:remove_not_used"].invoke

    puts "Create new definitions"
    Rake::Task["attribute_definitions:create_missing"].invoke

    puts "Update existing nested attributes"
    Rake::Task["attribute_definitions:update_existing_nested_attributes"].invoke

    puts "Update existing definitions validations"
    Rake::Task["attribute_definitions:update_existing_definitions_validations"].invoke
  end

  desc "Creates events for contract end and status change, remove not used attribute definitions"
  task remove_not_used: :environment do
    manage_employee_civil_status
    manage_employee_exit_date
    ids_to_remove = Employee::AttributeDefinition.where(name: definitions_to_remove).pluck(:id)
    Employee::AttributeVersion.where(attribute_definition_id: ids_to_remove).destroy_all
    Employee::AttributeDefinition.where(id: ids_to_remove).destroy_all
  end

  desc "Creates missing employee attributes definitions"
  task create_missing: :environment do
    Account.find_each do |account|
      account.update_default_attribute_definitions! unless all_attribute_definitions?(account)
    end
  end

  desc "Updates values for existing nested employee attributes"
  task update_existing_nested_attributes: :environment do
    Employee::AttributeVersion.where("data -> 'attribute_type' = 'Child'").find_each do |version|
      values = version.data.instance_values["data"]
      values["other_parent_working"] = values.delete("mother_is_working")
      version.save!
    end
  end

  desc "Updates validations for existing employee attribute definitions"
  task update_existing_definitions_validations: :environment do
    attributes = Account::ATTR_VALIDATIONS.keys
    Employee::AttributeDefinition.where(name: attributes, system: true).find_each do |definition|
      definition.update!(validation: Account::ATTR_VALIDATIONS[definition.name])
    end
  end

  def all_attribute_definitions?(account)
    account.employee_attribute_definitions
           .where(system: true)
           .count
           .eql?(Account::DEFAULT_ATTRIBUTES.values.flatten.uniq.count)
  end

  def definitions_to_remove
    Employee::AttributeDefinition.all.pluck(:name).uniq - Account::DEFAULT_ATTRIBUTES.values.flatten
  end

  def manage_employee_exit_date
    ids_to_remove = Employee::AttributeDefinition.where(name: "exit_date").pluck(:id)
    Employee::AttributeVersion.where(attribute_definition_id: ids_to_remove).map do |version|
      employee = version.employee
      event_effective_at = version.data.date.to_date
      next if event_effective_at <= employee.hired_date
      Employee::Event.create!(
        effective_at: event_effective_at, event_type: "contract_end", employee: employee
      )
      ::ContractEnd::Update.call(
        employee: employee,
        new_contract_end_date: event_effective_at,
        old_contract_end_date: event_effective_at
      )
    end
  end

  def manage_employee_civil_status
    ids_to_remove = Employee::AttributeDefinition.where(name: "civil_status").pluck(:id)
    Employee::AttributeVersion.where(attribute_definition_id: ids_to_remove).find_each do |version|
      next if version.attribute_definition.name.eql?("start_date")
      event_type = find_event_type_for(version)
      next if event_type.nil?
      event_effective_at = civil_event_effective_at(version)
      Employee::Event.create!(
        effective_at: event_effective_at, event_type: event_type, employee: version.employee
      )
    end
  end

  def find_event_type_for(version)
    event_type = Employee::CIVIL_STATUS.select { |_k, v| v.eql?(version.data.string) }.keys[0]
    return event_type if event_type.present?
    return "marriage" if MARRIAGE_STATUSES.include?(version.data.string)
  end

  def civil_event_effective_at(version)
    civil_date_definition =
      version.account.employee_attribute_definitions.find_by(name: "civil_status_date")
    civil_date =
      version
      .event
      .employee_attribute_versions
      .find_by(attribute_definition: civil_date_definition)

    civil_date.present? ? civil_date.data.date : version.event.effective_at - 1.day
  end
end
