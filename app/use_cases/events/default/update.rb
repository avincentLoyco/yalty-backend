module Events
  module Default
    class Update
      include AppDependencies[
        update_event_service: "services.event.update_event",
      ]

      def call(event, params)
        @event = event
        @params = params

        update_event
      end

      private

      attr_reader :event, :params

      def update_event
        update_event_service.new(event, params).call
      end

      def employee
        @employee ||= event.employee
      end

      def effective_at
        @effective_at ||= params[:effective_at]
      end
    end
  end
end
