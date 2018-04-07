module Events
  module Default
    class Destroy
      include ActiveSupport::Configurable

      pattr_initialize :event

      config_accessor :event_destroyer do
        DeleteEvent
      end

      class << self
        def call(event)
          new(event).call
        end
      end

      def call
        destroy_event
      end

      private

      def destroy_event
        event_destroyer.new(event).call
      end
    end
  end
end
