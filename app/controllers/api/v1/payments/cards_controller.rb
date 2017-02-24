module API
  module V1
    module Payments
      class CardsController < ApplicationController
        include CardsSchemas
        before_action :customer_exist

        def index
          authorize! :index, :payments
          render_resource(cards)
        end

        def create
          verified_dry_params(dry_validation_schema) do |attributes|
            authorize! :create, :payments
            resource = create_card(attributes[:token])
            resource.default = customer.default_source.nil?
            render json: resource_representer.new(resource).complete
          end
        end

        private

        def create_card(token)
          customer.sources.create(source: token)
        end

        def cards
          customer.sources.each { |card| card.default = customer.default_source.eql?(card.id) }
        end

        def customer
          @customer ||= Stripe::Customer.retrieve(Account.current.customer_id)
        end

        def customer_exist
          raise CustomerNotCreated, 'customer_id is empty' if Account.current.customer_id.nil?
        end

        def resource_representer
          ::Api::V1::Payments::CardsRepresenter
        end
      end
    end
  end
end
