module API
  module V1
    class PresencePoliciesController < ApplicationController
      authorize_resource except: [:create]
      include PresencePolicySchemas

      def show
        render_resource_with_relationships(resource)
      end

      def index
        response =
          filter_by_status.not_reset.map do |presence_policy|
            resource_representer.new(presence_policy).with_relationships
          end
        render json: response
      end

      def create
        verified_dry_params(dry_validation_schema) do |attributes|
          # TODO we need to require presence days always
          days_params = attributes.delete(:presence_days) if attributes.key?(:presence_days)
          resource = Account.current.presence_policies.new(attributes)
          authorize! :create, resource
          save!(resource)
          if days_params.present?
            Policy::Presence::CreateCompletePresencePolicy.new(
              resource.reload, days_params
            ).call
          end

          render_resource_with_relationships(resource, status: :created)
        end
      end

      def update
        verified_dry_params(dry_validation_schema) do |attributes|
          resource.attributes = attributes
          save!(resource)
          render_no_content
        end
      end

      def destroy
        verify_if_resource_not_locked!(resource)
        resource.destroy!
        render_no_content
      end

      private

      def save!(resource)
        raise InvalidResourcesError.new(resource, resource.errors.messages) unless resource.valid?
        resource.save!
      end

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
