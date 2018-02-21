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
          days_params = attributes.delete(:presence_days) if attributes.key?(:presence_days)
          related = related_params(attributes).compact
          resource = Account.current.presence_policies.new(attributes)
          authorize! :create, resource
          save!(resource, related)
          CreateCompletePresencePolicy.new(resource.reload, days_params).call if
            days_params.present?

          render_resource_with_relationships(resource, status: :created)
        end
      end

      def update
        verified_dry_params(dry_validation_schema) do |attributes|
          resource.attributes = attributes
          save!(resource, {})
          render_no_content
        end
      end

      def destroy
        verify_if_resource_not_locked!(resource)
        resource.destroy!
        render_no_content
      end

      private

      def related_params(attributes)
        related = {}

        attributes.each do |key, _value|
          if attributes[key].is_a?(Array) || attributes[key].nil?
            related.merge!(key => attributes.delete(key))
          end
        end

        related
      end

      def save!(resource, related)
        raise InvalidResourcesError.new(resource, resource.errors.messages) unless resource.valid?
        resource.save!
        assign_related(resource, related)
      end

      def assign_related(resource, related_records)
        return true if related_records.empty?
        related_records.each do |key, values|
          AssignCollection.new(resource, values, key.to_s).call
        end
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
