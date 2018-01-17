class AddUniqueIndexOnTimeOffPolicyAmount < ActiveRecord::Migration
  def change
    add_index :time_off_policies, [:amount, :time_off_category_id], unique: true, where: "(active IS TRUE AND reset IS FALSE)"
  end
end
