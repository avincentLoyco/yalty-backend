class SendDataToIntercom < ActiveJob::Base
  queue_as :intercom

  class JobWrapper < CustomJobAdapter::JobWrapper
    sidekiq_options unique: :until_executing, unique_args: ->(args) { args.first["arguments"] }
  end

  def perform(resource_id, resource_class)
    return unless intercom_client.present?

    resource = resource_class.constantize.find(resource_id)
    intercom_client.send(resource.intercom_type.to_sym).create(resource.intercom_data)
    log_event(resource.intercom_type.to_sym, resource.intercom_data)
  rescue Intercom::RateLimitExceeded
    self.class.set(wait: 1.minute).perform_later(resource_id, resource_class)
  end

  private

  def log_event(resource_type, data)
    Rails.logger.info "Sending data to intercom, resource_type: #{resource_type}, data: #{data}"
  end

  def intercom_client
    @intercom_client ||= IntercomService.new.client
  end
end
