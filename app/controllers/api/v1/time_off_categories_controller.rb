module API
  module V1
    class TimeOffCategoriesController < ApplicationController
      authorize_resource except: :create
      include TimeOffCategoriesRules

      def show
        render_resource(resource)
      end

      def index
        render_resource(resources)
      end

      def create
        verified_params(gate_rules) do |attributes|
          resource = Account.current.time_off_categories.new(attributes)
          authorize! :create, resource

          if resource.save
            render_resource(resource, status: :created)
          else
            resource_invalid_error(resource)
          end
        end
      end

      def update
        verified_params(gate_rules) do |attributes|
          if editable_resource.update(attributes)
            render_no_content
          else
            resource_invalid_error(resource)
          end
        end
      end

      def destroy
        if editable_resource.time_offs.empty?
          editable_resource.destroy!
          render_no_content
        else
          locked_error
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
