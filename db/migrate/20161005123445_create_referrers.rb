class CreateReferrers < ActiveRecord::Migration
  def change
    create_table :referrers, id: :uuid do |t|
      t.string :email, null: false, index: true, foreign_key: true
      t.string :token, null: false

      t.timestamps null: false
    end
  end
end
