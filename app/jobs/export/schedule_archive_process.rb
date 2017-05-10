module Export
  class ScheduleArchiveProcess < ActiveJob::Base
    queue_as :export

    class JobWrapper < CustomJobAdapter::JobWrapper
      sidekiq_options retry: 6
      sidekiq_retries_exhausted do |message|
        GlobalID::Locator.locate(
          message['args'].first['arguments'].first['_aj_globalid']
        ).update!(archive_processing: false)
      end
    end

    def perform(account)
      ::Export::CreateArchiveZip.new(account).call
      ExportMailer.archive_generation(account.id).deliver_now
      account.update!(archive_processing: false)
    end
  end
end
