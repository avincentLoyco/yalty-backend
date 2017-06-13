module Export
  class SendEmployeesJournal < ActiveJob::Base
    queue_as :export

    def perform(account)
      Dir.mktmpdir(account.subdomain) do |tmp_dir_path|
        journal_since = account.last_employee_journal_export
        journal_timestamp = Time.zone.now

        csv_file_path = ::Export::GenerateEmployeesJournal.new(
          account, journal_since, journal_timestamp, tmp_dir_path
        ).call

        if csv_file_path.present?
          Net::SFTP.start(
            ENV['LOYCO_SSH_HOST'],
            ENV['LOYCO_SSH_USER'],
            keys: [ENV['LOYCO_SSH_KEY_PATH']]
          ) do |sftp|
            sftp.upload!(
              csv_file_path.to_s, File.join(ENV['LOYCO_SSH_PATH'], csv_file_path.basename.to_s)
            )
          end

          account.update!(last_employee_journal_export: journal_timestamp)
        end
      end
    end
  end
end
