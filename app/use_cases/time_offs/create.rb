module TimeOffs
  class Create < UseCase
    attr_reader :attributes, :is_manager

    def initialize(attributes, is_manager: false)
      @attributes = attributes
      @is_manager = is_manager
    end

    include SubjectObservable

    def call
      TimeOff.transaction do
        auto_approved ? approve_time_off : notify_pending

        run_callback(:success, time_off)
      end
    end

    private

    def approve_time_off
      Approve.call(time_off) do |approve|
        approve.add_observers(*observers)
      end
    end

    def notify_pending
      notify_observers notification_type: :time_off_request, resource: time_off
    end

    def time_off
      @time_off ||= TimeOff.create!(attributes)
    end

    def auto_approved
      time_off.auto_approved? || is_manager
    end
  end
end
