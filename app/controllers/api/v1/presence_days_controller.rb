module API
  module V1
    class PresenceDaysController < ApplicationController

      def show
        render_resource(resource)
      end

      def index
        render_resource(resources)
      end

      private

      def resource
        @resource ||= resources.find(params[:id])
      end

      def resources
        @resources ||= presence_policy.presence_days
      end

      def presence_policy
        Account.current.presence_policies.find(params[:presence_policy_id])
      end

      def resource_representer
        ::V1::PresenceDayRepresenter
      end
    end
  end
end
