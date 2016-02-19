class AllowNullInYearsToEffect < ActiveRecord::Migration
  def change
    change_column_null :time_off_policies, :years_to_effect, true
    change_column_default :time_off_policies, :years_to_effect, nil
  end
end
