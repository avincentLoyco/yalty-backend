module Export
  class ScheduleEmployeesJournalExport < ActiveJob::Base
    queue_as :export

    def perform
      return unless ::Export::SendEmployeesJournal.enable?
      Account.with_yalty_access.find_each do |account|
        ::Export::SendEmployeesJournal.perform_later(account)
      end
    end
  end
end
