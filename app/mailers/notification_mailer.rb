class NotificationMailer < ApplicationMailer
  def time_off_request(recipients, resource)
    @employee = resource.employee
    @client_url = subdomain_url_for(recipients.first.account)
    notification_mail(recipients, resource)
  end

  def time_off_approved(recipients, resource)
    notification_mail(recipients, resource)
  end

  def time_off_declined(recipients, resource)
    notification_mail(recipients, resource)
  end

  private

  def notification_mail(recipients, resource)
    recipients.each do |recipient|
      @time_off = resource
      @firstname = recipient.employee.fullname
      time_off_category_name = @time_off.time_off_category.name

      I18n.with_locale(recipient.default_locale) do
        @time_off_category = I18n.t(
          time_off_category_name,
          scope: [:content, :time_off_categories],
          default: time_off_category_name.titleize
        )
        mail to: recipient.email
      end
    end
  end
end
