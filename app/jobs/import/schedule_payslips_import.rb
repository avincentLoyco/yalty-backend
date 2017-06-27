module Import
  class SchedulePayslipsImport < ActiveJob::Base
    queue_as :import

    def perform
      # TODO: Add specs
      return unless ::Import::ImportAndAssignPayslips.enable?

      Account.where(id: accounts_ids).find_each do |account|
        ::Import::ImportPayslipsJob.perform_later(account)
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
