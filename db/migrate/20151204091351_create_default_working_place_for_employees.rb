class CreateDefaultWorkingPlaceForEmployees < ActiveRecord::Migration
  def up
    Account.includes(:working_places, :employees).each do |account|
      working_place = account.working_places.create(name: 'Default')
      account.employees.each do |employee|
        employee.update(working_place: working_place)
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
