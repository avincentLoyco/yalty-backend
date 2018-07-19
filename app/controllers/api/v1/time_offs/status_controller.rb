module API
  module V1
    module TimeOffs
      class StatusController < ApplicationController
        def approve
          authorize! :approve, resource

          ::TimeOffs::Approve.call(resource) do |approve|
            approve.add_observers(
              internal_dispatcher, email_dispatcher, clear_notifications_observer
            )
            approve.on(:success) { head :no_content }
            approve.on(:not_modified) { head :no_content }
          end
        end

        def decline
          authorize! :decline, resource

          ::TimeOffs::Decline.call(resource) do |decline|
            decline.add_observers(
              internal_dispatcher, email_dispatcher, clear_notifications_observer
            )
            decline.on(:success) { head :no_content }
            decline.on(:not_modified) { head :no_content }
          end
        end

        private

        def resource
          @resource ||= Account.current.time_offs.find_by!(id: params[:time_off_id])
        end

        def clear_notifications_observer
          ::ClearNotificationsObserver.new
        end
      end
    end
  end
end
