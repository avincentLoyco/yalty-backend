module API
  module V1
    class WorkingPlacesController < ApplicationController
      authorize_resource except: :create
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
          authorize! :create, resource
          transactions do
            resource.save!
            assign_related(related)
          end
          render_resource(resource, status: :created)
        end
      end

      def update
        verified_params(gate_rules) do |attributes|
          related = related_params(attributes)
          transactions do
            resource.update(attributes)
            assign_related(related)
          end
          render_no_content
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
          assign_member(resource, value.try(:[], :id), key.to_s)
        end
      end

      def related_params(attributes)
        related = {}

        if attributes.key?(:holiday_policy)
          holiday_policy = { holiday_policy: attributes.delete(:holiday_policy) }
        end

        related.merge(holiday_policy.to_h)
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
