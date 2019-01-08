module Events
  module Default
    class Create
      include AppDependencies[
        create_event_service: "services.event.create_event",
      ]

      def call(params)
        @params = params
        event
      end

      private

      attr_reader :params

      def event
        @event ||= create_event_service.new(params, params[:employee_attributes].to_a).call
      end

      def employee
        @employee ||= Employee.find_by(id: params.dig(:employee, :id))
      end

      def effective_at
        @effective_at ||= params[:effective_at]
      end
    end
  end
end
