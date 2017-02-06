require 'active_support/concern'

module ActsAsIntercomTrigger
  extend ActiveSupport::Concern

  included do
    after_save :trigger_intercom_update
  end

  def trigger_intercom_update
    return trigger_from_employee if try(:employee).present?
    if try(:time_off_category).present?
      trigger_from_category
    else
      trigger_from_self
    end
  end

  private

  def trigger_from_self
    user.create_or_update_on_intercom(true) if try(:user).present?
    account.create_or_update_on_intercom(true) if try(:account).present?
  end

  def trigger_from_employee
    employee.user.create_or_update_on_intercom(true) if employee.try(:user).present?
    employee.account.create_or_update_on_intercom(true) if employee.try(:account).present?
  end

  def trigger_from_category
    return unless time_off_category.try(:account).present?
    time_off_category.account.create_or_update_on_intercom(true)
  end
end
