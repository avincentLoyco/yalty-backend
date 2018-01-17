class AddUniqueIndexOnTimeOffPolicyAmount < ActiveRecord::Migration
  def up
    execute <<-SQL
      CREATE UNIQUE INDEX time_off_policies_amount_constraint ON time_off_policies (amount, time_off_category_id) WHERE active IS TRUE AND reset IS FALSE;
    SQL
  end

  def down
    execute <<-SQL
      DROP INDEX time_off_policies_amount_constraint
    SQL
  end
end
