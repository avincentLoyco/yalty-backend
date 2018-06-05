module Export
  class ScheduleEmployeesJournalExport < ActiveJob::Base
    queue_as :export

    def perform
      return unless ::Export::SendEmployeesJournal.enable?
      Account.with_yalty_access.where(id: accounts_ids).find_each do |account|
        ::Export::SendEmployeesJournal.perform_later(account)
      end
    end

    private

    def accounts_ids
      ActiveRecord::Base.connection.execute("
        SELECT accounts.id
        FROM accounts, json_array_elements(accounts.available_modules->'data') data_set
        WHERE data_set ->> 'id' = 'automatedexport';
      ").values.flatten
    end
  end
end
