class ConvertEventEffectiveAtToDate < ActiveRecord::Migration
  def change
    # NOTE: Droping and recreating view is because of an error:
    #       PG::FeatureNotSupported: ERROR: cannot alter type of a column used by a view or rule
    drop_view :employee_attributes
    change_column :employee_events, :effective_at, :date
    create_view :employee_attributes, version: 4
  end
end
