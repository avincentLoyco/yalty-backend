class ApplicationMailer < ActionMailer::Base
  default from: ENV['YALTY_APP_EMAIL']
end
