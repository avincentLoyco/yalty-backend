# TODO: remove this file after all event use cases are refactored to use dependency injection

module Events
  module Default
    class Create
      include ActiveSupport::Configurable

      pattr_initialize :params

      config_accessor :event_creator do
        ::CreateEvent
      end

      class << self
        def call(params)
          new(params).call
        end
      end

      def call
        event
      end

      private

      def event
        @event ||= event_creator.new(params, params[:employee_attributes].to_a).call
      end
    end
  end
end
