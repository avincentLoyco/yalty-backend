module Export
  class ScheduleEmployeesJournalExport < ActiveJob::Base
    queue_as :export

    def perform
      return unless ::Export::SendEmployeesJournal.enable?
      Account.with_yalty_access.find_each do |account|
        next unless account.available_modules.include?('automatedexport')
        ::Export::SendEmployeesJournal.perform_later(account)
      end
    end
  end
end
