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
    return unless intercom_data_changed? || force
    return unless intercom_enabled?

    intercom_client.send(intercom_type.to_sym).create(intercom_data)
  end

  def intercom_client
    return unless intercom_enabled?

    @intercom_client ||= Intercom::Client.new(
      app_id: ENV['INTERCOM_APP_ID'],
      api_key: ENV['INTERCOM_API_KEY']
    )
  end

  def intercom_enabled?
    !Rails.env.test? && ENV['INTERCOM_APP_ID'].present? && ENV['INTERCOM_API_KEY'].present?
  end
end
