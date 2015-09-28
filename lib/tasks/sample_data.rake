namespace :yalty do
  desc <<-DESC
Load an account without any data.

Set ACCOUNT_SUBDOMAIN to choose the account to load.

take yalty:load_sample_account [ACCOUNT_SUBDOMAIN=my-company]
  DESC
  task load_sample_account: [:environment] do
    account = load_or_create_account
    user    = load_or_create_user(account)

    print_access_information(account, user)
  end

  desc <<-DESC
Load an account with a sample of data.

Set ACCOUNT_SUBDOMAIN to choose the account where to load sample data.

take yalty:load_sample_data [ACCOUNT_SUBDOMAIN=my-company]
  DESC
  task load_sample_data: [:environment] do
    account = load_or_create_account
    user    = load_or_create_user(account)

    # create or update employees
    [
      {uuid: 'dc85dc33-600a-4e12-a87d-1fd785478020', firstname: 'Hugo', lastname: 'Fray'},
      {uuid: '158c2005-baaf-4fbf-ba2c-1516c313a798', firstname: 'Lars', lastname: 'Weibel'}
    ].each do |data|
      ActiveRecord::Base.transaction do
        uuid = data.delete(:uuid)
        employee = account.employees.where(id: uuid).first
        employee = account.employees.create!(id: uuid) if employee.nil?

        if employee.events.empty?
          event = employee.events.create!(effective_at: 1.day.ago, event_type: 'hired')
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

    print_access_information(account, user)
  end
end

def load_or_create_account
  if ENV['ACCOUNT_SUBDOMAIN'].present?
    account = Account.where(subdomain: ENV['ACCOUNT_SUBDOMAIN']).first!
  else
    account   = Account.where(subdomain: 'my-company').first
    account ||= Account.create!(company_name: 'My Company')
  end

  account
end

def load_or_create_user(account)
  email = `git config user.email`
  email = 'test@example.com' if email.blank?

  user = account.users.where(email: email).first
  user || account.users.create!(email: email, password: '12345678')
end

def print_access_information(account, user)
  puts "app: http://#{account.subdomain}.yaltyapp.dev"
  puts 'api: http://api.yalty.dev'
  puts "email: #{user.email}"
  puts 'password: 12345678'
  puts "access token: #{user.access_token}"
end
