class CreateCompanyEvent < ActiveRecord::Migration
  def change
    create_table :company_events, id: :uuid do |t|
      t.string :title, null: false
      t.date :effective_at
      t.string :comment
      t.belongs_to :account, type: :uuid, index: true
      t.timestamps null: false
    end
  end
end
