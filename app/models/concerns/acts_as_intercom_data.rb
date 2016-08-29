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

    Resque.enqueue_at_with_queue(
      'intercom',
      3.minutes.from_now,
      SendDataToIntercom,
      id,
      self.class.name
    )
  end

  private

  def job_not_on_queue
    delayed_jobs.none? { |job| job.match(id) }
  end

  def delayed_jobs
    @delayed_jobs ||= Resque.redis.keys('timestamps:*')
      .select {|key| key =~ /"queue":"intercom"/ && key =~ /"#{self.class.name}"/ }
  end
end
