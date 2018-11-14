module Events
  module WorkContract
    class Update
      include AppDependencies[update_event_service: "services.event.update_event"]

      def call(event, params)
        update_event_service.new(event, params).call
      end
    end
  end
end
