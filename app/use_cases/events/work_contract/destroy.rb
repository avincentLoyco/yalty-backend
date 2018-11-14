module Events
  module WorkContract
    class Destroy
      include AppDependencies[delete_event_service: "services.event.delete_event"]

      def call(event)
        delete_event_service.new(event).call
      end
    end
  end
end
