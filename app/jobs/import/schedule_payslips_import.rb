module Import
  class SchedulePayslipsImport < ActiveJob::Base
    queue_as :import

    def perform
      return unless ::Import::ImportAndAssignPayslips.enable?

      Net::SFTP.start(
        ENV["LOYCO_SSH_HOST"],
        ENV["LOYCO_SSH_USER"],
        keys: [ENV["LOYCO_SSH_KEY_PATH"]]
      ) do |sftp|
        sftp.dir.glob(ENV["LOYCO_SSH_IMPORT_PAYSLIPS_PATH"], "**/*.pdf") do |entry|
          ::Import::ImportPayslipsJob.perform_later(entry.name)
        end
      end
    end
  end
end
