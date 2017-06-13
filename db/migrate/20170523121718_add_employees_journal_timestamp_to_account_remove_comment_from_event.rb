class AddEmployeesJournalTimestampToAccountRemoveCommentFromEvent < ActiveRecord::Migration
  def change
    add_column :accounts, :last_employee_journal_export, :datetime
    remove_column :employee_events, :comment
  end
end
