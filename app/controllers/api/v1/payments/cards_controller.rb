module API
  module V1
    module Payments
      class CardsController < ApplicationController
        include CardsSchemas
        include PaymentsHelper

        def index
          render_resource(cards)
        end

        def create
          verified_dry_params(dry_validation_schema) do |attributes|
            resource = create_card(attributes[:token])
            resource.default = customer.default_source.nil?
            render json: resource_representer.new(resource).complete
          end
        end

        def update
          customer.default_source = params[:id]
          customer.save
          render_no_content
        end

        def destroy
          customer.sources.retrieve(params[:id]).delete
          render_no_content
        end

        private

        def create_card(token)
          customer.sources.create(source: token)
        end

        def cards
          customer.sources.each { |card| card.default = customer.default_source.eql?(card.id) }
        end

        def resource_representer
          ::Api::V1::Payments::CardRepresenter
        end

        def stripe_error(exception)
          error = StripeError.new(
            type: "card",
            field: error_field,
            message: exception.message,
            code: exception.try(:code) || "proxy_gateway_error"
          )
          render json: ::Api::V1::StripeErrorRepresenter.new(error).complete, status: 502
        end

        def error_field
          if params.key?(:token) then "token"
          elsif params.key?(:id) then "id"
          end
        end
      end
    end
  end
end
