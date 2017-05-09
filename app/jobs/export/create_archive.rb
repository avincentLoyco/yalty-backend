module Export
  class CreateArchive < ActiveJob::Base
    queue_as :export

    # TODO: Add JobWraper when it's merged PR #349

    def perform(account)

    end
  end
end
