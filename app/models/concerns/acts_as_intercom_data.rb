require 'active_support/concern'

module ActsAsIntercomData
  extend ActiveSupport::Concern

  included do
    after_save :create_or_update_on_intercom
  end

  def intercom_type
  end

  def intercom_attributes
    []
  end

  def intercom_data
    {}
  end

  def intercom_data_changed?
    (changed & intercom_attributes).present?
  end

  def create_or_update_on_intercom(force = false)
    return unless (intercom_data_changed? || force) && job_not_on_queue

    Sidekiq::Client.enqueue_to_in(
      'intercom',
      3.minutes.from_now,
      SendDataToIntercom,
      id,
      self.class.name
    )
  end

  private

  def job_not_on_queue
    delayed_jobs.none? do |job|
      job.args.to_s.match(id)
    end
  end

  def delayed_jobs
    intercom_jobs.select { |job| job.queue.eql?('intercom') && job.args.include?(self.class.name) }
  end

  def intercom_jobs
    Sidekiq::ScheduledSet.new
  end
end
