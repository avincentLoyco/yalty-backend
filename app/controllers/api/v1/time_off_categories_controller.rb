module API
  module V1
    class TimeOffCategoriesController < ApplicationController
      include TimeOffCategoriesSchemas

      def show
        authorize! :show, Account.current
        render_resource(resource)
      end

      def index
        render_resource(resources)
      end

      def create
        verified_dry_params(dry_validation_schema) do |attributes|
          ActiveRecord::Base.transaction do
            resource = Account.current.time_off_categories.new(attributes)
            authorize! :create, resource
            resource.save!
            Policy::TimeOff::CreateCounterForCategory.call(resource)
            render_resource(resource, status: :created)
          end
        end
      end

      def update
        authorize! :create, resource
        verified_dry_params(dry_validation_schema) do |attributes|
          attributes.delete(:name) if resource.system?
          resource.update!(attributes)
          render_no_content
        end
      end

      def destroy
        authorize! :create, editable_resource
        if editable_resource.time_offs.empty?
          editable_resource.destroy!
          render_no_content
        else
          render_locked_error(controller_name, "time-off")
        end
      end

      private

      def resource
        @resource ||= resources.find(params[:id])
      end

      def editable_resource
        @editable_resource ||= resources.editable.find(params[:id])
      end

      def resources
        @resources ||= Account.current.time_off_categories
      end

      def resource_representer
        ::Api::V1::TimeOffCategoryRepresenter
      end
    end
  end
end
