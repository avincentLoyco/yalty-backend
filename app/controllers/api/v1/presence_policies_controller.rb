module API
  module V1
    class PresencePoliciesController < ApplicationController
      include PresencePolicyRules

      def show
        render_resource_with_relationships(resource)
      end

      def index
        render_resource(resources)
      end

      def create
        verified_params(gate_rules) do |attributes|
          related = related_params(attributes).compact
          resource = Account.current.presence_policies.new(attributes)

          transactions do
            save!(resource, related)
          end

          render_resource_with_relationships(resource, status: :created)
        end
      end

      def update
        verified_params(gate_rules) do |attributes|
          related = related_params(attributes).compact

          transactions do
            resource.attributes = attributes
            save!(resource, related)
          end

          render_no_content
        end
      end

      def destroy
        if resource.employees.empty? && resource.working_places.empty?
          resource.destroy!
          render_no_content
        else
          locked_error
        end
      end

      private

      def related_params(attributes)
        related = {}

        attributes.each do |key, value|
          if attributes[key].kind_of?(Array)
            related.merge!({key => attributes.delete(key)})
          end
        end

        related
      end

      def save!(resource, related)
        assign_related(resource, related)

        unless resource.save && related_errors_messages(resource, related).blank?
          related_messages = related_errors_messages(resource, related)

          messages = resource.errors.messages.to_h
          related_messages.each do |message|
            messages.merge!(message)
          end

          fail InvalidResourcesError.new(resource, messages)
        end
      end

      def related_errors_messages(resource, related)
        errors = []

        related.keys.each do |relate|
          resource.send(relate.to_s).each do |record|
            errors.push(record.errors.messages) if record.errors.any?
          end
        end

        errors
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
        render response.merge(json: resource_representer.new(resource).with_relationships)
      end

      def resource_representer
        ::Api::V1::PresencePolicyRepresenter
      end
    end
  end
end
