module API
  module V1
    class PresenceDaysController < ApplicationController
      authorize_resource except: :create
      include PresenceDaySchemas

      def show
        render_resource(resource)
      end

      def index
        render_resource(resources)
      end

      def create
        verified_dry_params(dry_validation_schema) do |attributes|
          resource = presence_policy.presence_days.new(presence_day_params(attributes))
          authorize! :create, resource

          resource.save!
          render_resource(resource, status: :created)
        end
      end

      def update
        verified_dry_params(dry_validation_schema) do |attributes|
          previous_order = resource.order

          transactions do
            resource.update!(attributes)
            update_affected_balances(resource.presence_policy) if previous_order != resource.order
          end
          render_no_content
        end
      end

      def destroy
        if resource.time_entries.empty?
          transactions do
            update_affected_balances(resource.presence_policy)
            resource.destroy!
          end
          render_no_content
        else
          locked_error
        end
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
