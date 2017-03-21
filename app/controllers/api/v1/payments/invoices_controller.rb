module API
  module V1
    module Payments
      class InvoicesController < ApplicationController
        include PaymentsHelper

        def index
          render_resource(invoices)
        end

        private

        def invoices
          Account.current.invoices.order(:date)
        end

        def resource_representer
          ::Api::V1::Payments::InvoiceRepresenter
        end
      end
    end
  end
end
