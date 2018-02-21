require "sidekiq"

class CustomJobAdapter
  class << self
    def enqueue(job)
      # Sidekiq::Client does not support symbols as keys
      Sidekiq::Client.push \
        "class"   => wrapper_for(job),
        "wrapped" => job.class.to_s,
        "queue"   => job.queue_name,
        "args"    => [job.serialize]
    end

    def enqueue_at(job, timestamp)
      Sidekiq::Client.push \
        "class"   => wrapper_for(job),
        "wrapped" => job.class.to_s,
        "queue"   => job.queue_name,
        "args"    => [job.serialize],
        "at"      => timestamp
    end

    def wrapper_for(job)
      job.class.const_get(:JobWrapper)
    rescue NameError
      ::CustomJobAdapter::JobWrapper
    end
  end

  class JobWrapper #:nodoc:
    include Sidekiq::Worker

    def perform(job_data)
      ActiveJob::Base.execute job_data
    end
  end
end
