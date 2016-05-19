module API
  module V1
    class PresencePoliciesController < ApplicationController
      authorize_resource except: :create
      include PresencePolicyRules

      def show
        render_resource_with_relationships(resource)
      end

      def index
        response =
          resources.map do |item|
            resource_representer.new(item, current_user).with_relationships
          end
        render json: response
      end

      def create
        verified_params(gate_rules) do |attributes|
          days_params = attributes.delete(:presence_days) if attributes.key?(:presence_days)
          related = related_params(attributes).compact
          resource = Account.current.presence_policies.new(attributes)
          authorize! :create, resource

          transactions do
            save!(resource, related)
            CreateCompletePresencePolicy.new(resource.reload, days_params).call if
              days_params.present?
          end

          render_resource_with_relationships(resource, status: :created)
        end
      end

      def update
        verified_params(gate_rules) do |attributes|
          transactions do
            resource.attributes = attributes
            save!(resource, {})
          end

          render_no_content
        end
      end

      def destroy
        if resource.employees.empty? && resource.presence_days.empty?
          resource.destroy!
          render_no_content
        else
          locked_error
        end
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
          assign_collection(resource, values, key.to_s)
        end
      end

      def resource
        @resource ||= resources.find(params[:id])
      end

      def resources
        @resources ||= Account.current.presence_policies
      end

      def render_resource_with_relationships(resource, response = {})
        render response.merge(json: resource_representer.new(resource, current_user).with_relationships)
      end

      def resource_representer
        ::Api::V1::PresencePolicyRepresenter
      end
    end
  end
end
