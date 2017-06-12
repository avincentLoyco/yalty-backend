module Export
  class SendEmployeesJournal < ActiveJob::Base
    queue_as :export

    def perform(account)
      Dir.mktmpdir(account.subdomain) do |tmp_dir_path|
        csv_file_path = ::Export::GenerateEmployeesJournal.new(account, tmp_dir_path).call

        Net::SFTP.start(
          ENV['LOYCO_SSH_HOST'],
          ENV['LOYCO_SSH_USER'],
          keys: [ENV['LOYCO_SSH_KEY_PATH']]
        ) do |sftp|
          sftp.upload!(
            csv_file_path.to_s, File.join(ENV['LOYCO_SSH_PATH'], csv_file_path.basename.to_s)
          )
        end
      end
    end
  end
end
