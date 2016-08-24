class SendDataToIntercom
  @queue = :intercom

  def self.perform(resource_id, resource_class)
    return unless intercom_client.present?

    resource = resource_class.constantize.find(resource_id)
    intercom_service.client.send(resource.intercom_type.to_sym).create(resource.intercom_data)
  end

  private

  def intercom_client
    @intercom_client ||= IntercomService.new.client
  end
end
