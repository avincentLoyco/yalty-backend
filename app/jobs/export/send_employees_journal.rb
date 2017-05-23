module Export
  class SendEmployeesJournal < ActiveJob::Base
    queue_as :export

    def perform(account)
      Dir.mktmpdir(account.subdomain) do |tmp_dir_path|
        csv_file_path = ::Export::GenerateEmployeesJournal.new(account, tmp_dir_path).call

        Net::SCP.upload!(
          ENV['LOYCO_SSH_HOST'],
          ENV['LOYCO_SSH_USER'],
          csv_file_path.to_s,
          csv_file_path.split.last.to_s,
          ssh: { keys: [ENV['LOYCO_SSH_KEY_PATH']] }
        )
      end
    end
  end
end
