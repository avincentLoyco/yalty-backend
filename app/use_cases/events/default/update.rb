module Events
  module Default
    class Update
      include ActiveSupport::Configurable

      pattr_initialize :event, :params

      config_accessor :event_updater do
        ::UpdateEvent
      end

      class << self
        def call(event, params)
          new(event, params).call
        end
      end

      def call
        update_event
      end

      private

      def update_event
        event_updater.new(event, params).call
      end
    end
  end
end
