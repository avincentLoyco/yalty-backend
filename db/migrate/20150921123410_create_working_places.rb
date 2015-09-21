class CreateWorkingPlaces < ActiveRecord::Migration
  def up
    create_table :working_places do |t|
      t.string :name, null: false
      t.references :account, index: true, foreign_key: { on_delete: :cascade }
      t.timestamps null: false
    end
  end

  def down
    drop_table :working_places
  end
end
