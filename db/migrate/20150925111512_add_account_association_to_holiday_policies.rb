class AddAccountAssociationToHolidayPolicies < ActiveRecord::Migration
  def change
    add_reference :holiday_policies, :account, index: true, foreign_key: true
  end
end
