module API
  module V1
    class WorkingPlacesController < ApplicationController
      authorize_resource except: :create
      include WorkingPlaceSchemas

      def index
        render_resource(resources_by_status(WorkingPlace, EmployeeWorkingPlace))
      end

      def show
        render_resource(resource)
      end

      def create
        verified_dry_params(dry_validation_schema) do |attributes|
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
        verified_dry_params(dry_validation_schema) do |attributes|
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
          AssignMember.new(resource, value.try(:[], :id), key.to_s).call
        end
      end

      def related_params(attributes)
        related = {}

        if attributes.key?(:holiday_policy)
          holiday_policy = { holiday_policy: attributes.delete(:holiday_policy) }
        end

        related.merge(holiday_policy.to_h)
      end

      def resource
        @resource ||= Account.current.working_places.find(params[:id])
      end

      def resource_representer
        ::Api::V1::WorkingPlaceRepresenter
      end
    end
  end
end
