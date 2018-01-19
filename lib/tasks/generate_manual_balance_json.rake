task generate_manual_balance_json: :environment do
  folder                = Pathname.new('db/clients/with_policy/')
  folder_without_policy = Pathname.new('db/clients/without_policy')

  folder.children.each do |filename|
    create_manual_balances(filename, Date.new(2017, 12, 30))
  end

  folder_without_policy.children.each do |filename|
    create_manual_balances(filename, Date.new(2018, 1, 1))
  end
end

def create_manual_balances(filename, date)
  file                 = File.read(filename)
  employees_hash       = JSON.parse(file)
  account              = Employee.find(employees_hash.first.first).account
  time_off_category_id = account.time_off_categories.find_by(name: 'vacation').id

  employees_hash.each do |data|
    employee    = Employee.find(data.first)
    new_balance = data.second

    CreateEmployeeBalance.new(time_off_category_id,
                              employee.id,
                              account.id,
                              balance_type: 'manual_adjustment',
                              resource_amount: new_balance,
                              manual_amount: 0,
                              effective_at: date).call
  end
end
