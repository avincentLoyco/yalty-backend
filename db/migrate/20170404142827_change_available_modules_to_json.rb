class ChangeAvailableModulesToJson < ActiveRecord::Migration
  def change
    add_column :accounts, :available_modules_tmp, :json

    Account.connection.execute('SELECT id, available_modules FROM accounts').values.each do |row|
      data = row.second[1..-2].split(",").inject([]) do |data, plan_id|
        data.push({ id: plan_id, canceled: false })
        data
      end

      Account.find(row.first).update!(available_modules_tmp: { data: data })
    end

    remove_column :accounts, :available_modules, :text, array: true
    add_column    :accounts, :available_modules, :json

    Account.update_all('available_modules=available_modules_tmp')

    remove_column :accounts, :available_modules_tmp, :json
  end
end
