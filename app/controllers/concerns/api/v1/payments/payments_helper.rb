module API
  module V1
    module Payments
        module PaymentsHelper
          extend ActiveSupport::Concern
          include Exceptions

          included do
            before_action :customer_exist, :authorize_payments
          end

          def customer
            @customer ||= Stripe::Customer.retrieve(Account.current.customer_id)
          end

          def customer_exist
            raise CustomerNotCreated, 'customer_id is empty' if Account.current.customer_id.nil?
          end

          def authorize_payments
            authorize!(action_name.to_sym, :payments)
          end
        end
    end
  end
end
