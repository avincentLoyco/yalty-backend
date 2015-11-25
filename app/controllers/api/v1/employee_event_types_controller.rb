module API
  module V1
    class EmployeeEventTypesController < API::ApplicationController
      before_action :check_event_type, only: :show

      def show
        event_type_attributes = event_attributes[event_type.to_sym]
        render json: representer.new(event_type, event_type_attributes)
      end

      def index
        response = event_attributes.map do |key, values|
          representer.new(key.to_s, values).basic
        end

        render json: response
      end

      private

      def event_type
        @event_type ||= params[:employee_event_type]
      end

      def representer
        ::Api::V1::EmployeeEventTypeRepresenter
      end

      def check_event_type
        unless Employee::Event.event_types.include?(event_type)
          fail EventTypeNotFoundError.new(event_type, message: 'Event Type Not Found')
        end
      end

      def event_attributes
        Employee::Event::EVENT_ATTRIBUTES
      end
    end
  end
end
