class RemoveTimeOffOtherCategory < ActiveRecord::Migration
  def up
    execute("""
      DELETE FROM time_off_categories WHERE time_off_categories.id IN (
        SELECT time_off_categories.id FROM time_off_categories
        LEFT JOIN time_off_policies
        ON time_off_policies.time_off_category_id = time_off_categories.id
        WHERE time_off_categories.name = 'other'
        GROUP BY time_off_categories.id
        HAVING COUNT(time_off_policies.id) = 0
      );

      UPDATE time_off_categories SET system = false WHERE name = 'other';
    """)
  end
end
