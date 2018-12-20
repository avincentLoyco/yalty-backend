# frozen_string_literal: true

module API
  module V1
    class PresencePoliciesController < ApplicationController
      include PresencePolicySchemas
      include AppDependencies[
        create_presence_policy: "use_cases.presence_policies.create",
        archive_presence_policy: "use_cases.presence_policies.archive",
        update_presence_policy: "use_cases.presence_policies.update",
      ]

      authorize_resource except: [:create]

      def show
        render_resource_with_relationships(resource)
      end

      def index
        response =
          filter_by_status.not_reset.not_archived.map do |presence_policy|
            resource_representer.new(presence_policy).with_relationships
          end
        render json: response
      end

      def create
        authorize! :create, PresencePolicy

        verified_dry_params(dry_validation_schema) do |attributes|
          days_params = attributes.delete(:presence_days)
          default_full_time = attributes.delete(:default_full_time)

          resource = create_presence_policy.call(
            account: Account.current,
            params: attributes,
            days_params: days_params,
            default_full_time: default_full_time,
          )

          render_resource_with_relationships(resource, status: :created)
        end
      end

      def update
        verified_dry_params(dry_validation_schema) do |attributes|
          default_full_time = attributes.delete(:default_full_time)

          update_presence_policy.call(
            presence_policy: resource,
            params: attributes,
            default_full_time: default_full_time,
          )

          render_no_content
        end
      end

      def destroy
        archive_presence_policy.call(presence_policy: resource)
        render_no_content
      end

      private

      def resource
        @resource ||= resources.find(params[:id])
      end

      def resources
        @resources ||= Account.current.presence_policies
      end

      def render_resource_with_relationships(resource, response = {})
        render response.merge(
          json: resource_representer.new(resource).with_relationships
        )
      end

      def resource_representer
        ::Api::V1::PresencePolicyRepresenter
      end

      def filter_by_status
        status = params[:status] ? params[:status].eql?("active") : true
        resources.where(active: status)
      end
    end
  end
end
