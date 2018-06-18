class NotificationMailer < ApplicationMailer
  def time_off_request(recipient, resource)
    @employee = resource.employee
    @client_url = subdomain_url_for(recipient.account)
    notification_mail(recipient, resource)
  end

  def time_off_approved(recipient, resource)
    notification_mail(recipient, resource)
  end

  def time_off_declined(recipient, resource)
    notification_mail(recipient, resource)
  end

  private

  def notification_mail(recipient, resource)
    @time_off = resource
    @time_off_category = @time_off.time_off_category.name
    @firstname = recipient.employee.fullname

    I18n.with_locale(recipient.default_locale) do
      mail to: recipient.email
    end
  end
end
