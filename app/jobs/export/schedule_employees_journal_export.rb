module Export
  class ScheduleEmployeesJournalExport < ActiveJob::Base
    queue_as :export

    def perform
      return unless enable?
      Account.with_yalty_access.find_each do |account|
        ::Export::SendEmployeesJournal.perform_later(account)
      end
    end

    private

    def enable?
      [ENV['LOYCO_SSH_HOST'], ENV['LOYCO_SSH_USER'], ENV['LOYCO_SSH_KEY_PATH']].all?(&:present?)
    end
  end
end
