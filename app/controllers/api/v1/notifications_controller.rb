module API
  module V1
    class NotificationsController < ApplicationController
      def index
        render_resource(resources)
      end

      def read
        resource.update!(seen: true)
        head :no_content
      end

      private

      def resource
        @resource ||= current_user.notifications.find params[:notification_id]
      end

      def resources
        current_user.notifications.unread
      end

      def resource_representer
        ::Api::V1::NotificationRepresenter
      end
    end
  end
end
