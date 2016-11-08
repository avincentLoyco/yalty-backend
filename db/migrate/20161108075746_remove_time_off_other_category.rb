class RemoveTimeOffOtherCategory < ActiveRecord::Migration
  def up
    execute("""
      DELETE FROM time_off_categories toc
      USING time_off_policies top
      WHERE toc.id != top.time_off_category_id AND toc.name = 'other';

      UPDATE time_off_categories SET system = false WHERE name = 'other';
    """)
  end
end
