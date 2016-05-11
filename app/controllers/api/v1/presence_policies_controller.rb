module API
  module V1
    class PresencePoliciesController < ApplicationController
      authorize_resource except: :create
      include PresencePolicyRules

      def show
        render_resource_with_relationships(resource)
      end

      def index
        response = resources.map { |item| resource_representer.new(item, current_user).with_relationships }
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
            update_affected_balances(nil, resource.affected_employees)
          end

          render_resource_with_relationships(resource, status: :created)
        end
      end

      def update
        verified_params(gate_rules) do |attributes|
          related = related_params(attributes)
          previously_affected = resource.affected_employees
          # Without below line query is not performed after update what influences
          # calculations result.
          previously_affected.present?

          transactions do
            resource.attributes = attributes
            save!(resource, related)
            update_affected_balances(nil, employees_to_update(previously_affected))
          end

          render_no_content
        end
      end

      def destroy
        if resource.employees.empty?
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

      def employees_to_update(previously_affected)
        (resource.affected_employees.pluck(:id) + previously_affected).uniq -
          (resource.affected_employees.pluck(:id) & previously_affected)
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
