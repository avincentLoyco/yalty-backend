module TimeOffs
  class Create < UseCase
    pattr_initialize :attributes

    include SubjectObservable

    def call
      TimeOff.transaction do
        time_off.auto_approved? ? approve_time_off : notify_pending

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
  end
end
