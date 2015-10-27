module API
  module V1
    class PresenceDaysController < ApplicationController
      include PresenceDayRules

      def show
        render_resource(resource)
      end

      def index
        render_resource(resources)
      end

      def create
        verified_params(gate_rules) do |attributes|
          resource = presence_policy.presence_days.new(attributes)
          if resource.save
            render_resource(resource, status: :created)
          else
            resource_invalid_error(resource)
          end
        end
      end

      def update
        verified_params(gate_rules) do |attributes|
          if resource.update(attributes)
            render_no_content
          else
            resource_invalid_error(resource)
          end
        end
      end

      def destroy
        resource.destroy!
        render_no_content
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
