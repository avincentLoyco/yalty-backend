module API
  module V1
    class PresenceDaysController < ApplicationController
      authorize_resource except: :create
      include PresenceDaySchemas
      include AppDependencies[
        create_presence_day: "use_cases.presence_days.create",
        destroy_presence_day: "use_cases.presence_days.destroy",
        update_presence_day: "use_cases.presence_days.update",
      ]

      def show
        render_resource(resource)
      end

      def index
        render_resource(resources)
      end

      def create
        authorize! :create, PresenceDay

        verified_dry_params(dry_validation_schema) do |attributes|
          resource = create_presence_day.call(
            params: presence_day_params(attributes),
            presence_policy: presence_policy,
          )
          render_resource(resource, status: :created)
        end
      end

      def update
        verified_dry_params(dry_validation_schema) do |attributes|
          update_presence_day.call(presence_day: resource, params: attributes)
          render_no_content
        end
      end

      def destroy
        destroy_presence_day.call(presence_day: resource)
        render_no_content
      end

      private

      def resource
        @resource ||= Account.current.presence_days.find(params[:id])
      end

      def resources
        @resources ||= presence_policy.presence_days
      end

      def presence_policy
        @presence_policy ||= Account.current.presence_policies.find(presence_policy_params)
      end

      def presence_day_params(attributes)
        attributes.tap { |attr| attr.delete(:presence_policy) }
      end

      def presence_policy_params
        params[:presence_policy_id] ? params[:presence_policy_id] : params[:presence_policy][:id]
      end

      def resource_representer
        ::Api::V1::PresenceDayRepresenter
      end
    end
  end
end
