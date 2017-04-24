require 'active_support/concern'

module ActsAsIntercomData
  extend ActiveSupport::Concern

  included do
    after_save :create_or_update_on_intercom
  end

  def intercom_type; end

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

    SendDataToIntercom
      .set(wait: 3.minutes)
      .perform_later(id, self.class.name)
  end
end
