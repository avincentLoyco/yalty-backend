module Events
  module Default
    class Destroy
      include AppDependencies[
        delete_event_service: "services.event.delete_event"
      ]

      def call(event)
        @event = event
        destroy_event
      end

      private

      attr_reader :event

      def destroy_event
        delete_event_service.new(event).call
      end

      def employee
        @employee ||= event.employee
      end

      def effective_at
        @effective_at ||= event.effective_at
      end
    end
  end
end
