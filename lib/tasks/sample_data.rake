task load_sample_data: [:environment] do
  raise "set the account subdomain with ACCOUNT_SUBDOMAIN env" if ENV['ACCOUNT_SUBDOMAIN'].nil?

  account = Account.where(subdomain: ENV['ACCOUNT_SUBDOMAIN']).first!

  [
    {uuid: 'dc85dc33-600a-4e12-a87d-1fd785478020', firstname: 'Hugo', lastname: 'Fray'},
    {uuid: '158c2005-baaf-4fbf-ba2c-1516c313a798', firstname: 'Lars', lastname: 'Weibel'}
  ].each do |data|
    ActiveRecord::Base.transaction do
      uuid = data.delete(:uuid)
      employee = account.employees.where(uuid: uuid).first
      employee = account.employees.create!(uuid: uuid) if employee.nil?

      if employee.events.empty?
        event = employee.events.create!(effective_at: 1.day.ago)
      else
        event = employee.events.order('id ASC').first
      end

      data.each do |key, value|
        attribute = event.employee_attribute_versions
          .joins(:attribute_definition)
          .where('employee_attribute_definitions.name = ?', key)
          .first

        if attribute.nil?
          attribute_definition = account.employee_attribute_definitions
            .where(name: key)
            .first!

          attribute = event.employee_attribute_versions.build(
            employee: event.employee,
            attribute_definition: attribute_definition
          )
        end

        attribute.data.string = value
        attribute.save!
      end
    end
  end

end
