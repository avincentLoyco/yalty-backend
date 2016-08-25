require 'active_support/concern'

module ActsAsIntercomTrigger
  extend ActiveSupport::Concern

  included do
    after_save :trigger_intercom_update
  end

  def trigger_intercom_update
    user.create_or_update_on_intercom(true) if try(:user).present?
    account.create_or_update_on_intercom(true) if try(:account).present?
  end
end
