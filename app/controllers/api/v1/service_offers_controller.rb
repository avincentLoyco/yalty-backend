module API
  module V1
    class ServiceOffersController < ApplicationController
      def create
        case params[:meta][:action]
        when 'book-now'
          ServiceRequestMailer
            .book_request(Account.current, Account::User.current, params)
            .deliver_later
        when 'send-quote'
          ServiceRequestMailer
            .quote_request(Account.current, Account::User.current, params)
            .deliver_later
        end
        render_no_content
      end
    end
  end
end
