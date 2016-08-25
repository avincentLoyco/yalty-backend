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
    !send(self.class.name.downcase.split('::').last + '_delayed_jobs').any? { |job| job.match(id) }
  end

  def account_delayed_jobs
    @account_delayed_jobs ||= delayed_jobs.map do |job|
      job if job =~ /Account/ && !(job =~ /User/)
    end.compact
  end

  def user_delayed_jobs
    @user_delayed_jobs ||= delayed_jobs.map { |job| job if job =~ /User/ }.compact
  end

  def intercom_jobs
    return unless delayed_jobs.present?

    @intercom_jobs ||= delayed_jobs.map { |job| job if job =~ /intercom/ }
  end

  def delayed_jobs
    @delayed_jobs ||= Resque.redis.keys('delayed:[0-9]*')
      .map { |key| Resque.redis.lrange(key, 0, -1) }
      .flatten
  end
end
