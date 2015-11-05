module API
  module V1
    class WorkingPlacesController < ApplicationController
      include WorkingPlaceRules

      def index
        render_resource(resources)
      end

      def show
        render_resource(resource)
      end

      def create
        verified_params(gate_rules) do |attributes|
          related = related_params(attributes)
          @resource = Account.current.working_places.new(attributes)
          result = transactions do
            resource.save &&
              assign_related(related)
          end
          if result
            render_resource(resource, status: :created)
          else
            resource_invalid_error(resource)
          end
        end
      end

      def update
        verified_params(gate_rules) do |attributes|
          related = related_params(attributes)
          result = transactions do
            resource.update(attributes) &&
              assign_related(related)
          end
          if result
            render_no_content
          else
            resource_invalid_error(resource)
          end
        end
      end

      def destroy
        if resource.employees.blank?
          resource.destroy!
          render_no_content
        else
          locked_error
        end
      end

      private

      def assign_related(related_records)
        return true if related_records.empty?
        related_records.each do |key, value|
          if members.include?(key)
            assign_member(resource, value.try(:[], :id), key.to_s)
          else
            assign_collection(resource, value, key.to_s)
          end
        end
      end

      def related_params(attributes)
        related = {}
        employees =
          { employees: attributes.delete(:employees) } if attributes.key?(:employees)
        holiday_policy =
          { holiday_policy: attributes.delete(:holiday_policy) } if attributes.key?(:holiday_policy)
        presence_policy =
          { presence_policy: attributes.delete(:presence_policy) } if attributes
              .key?(:presence_policy)
        related.merge(employees.to_h)
          .merge(holiday_policy.to_h)
          .merge(presence_policy.to_h)
      end

      def members
        %i(presence_policy holiday_policy)
      end

      def resources
        @resources ||= Account.current.working_places
      end

      def resource
        @resource ||= resources.find(params[:id])
      end

      def resource_representer
        ::Api::V1::WorkingPlaceRepresenter
      end
    end
  end
end
