# spec/support/message_delivery.rb
class ActionMailer::MessageDelivery
  def deliver_later
    deliver_now
  end
end
