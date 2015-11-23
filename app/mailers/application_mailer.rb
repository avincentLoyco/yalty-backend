class ApplicationMailer < ActionMailer::Base
  default from: ENV['YALTY_APP_EMAIL']

  def send_mail(email, subject, body)
    mail(
      to:           email,
      subject:      subject,
      body:         body,
      content_type: 'text/plain'
    )
  end
end
