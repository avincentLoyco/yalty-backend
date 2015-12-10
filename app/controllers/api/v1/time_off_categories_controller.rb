module API
  module V1
    class TimeOffCategoriesController < ApplicationController
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

          if resource.save
            render_resource(resource)
          else
            resource_invalid_error(resource)
          end
        end
      end

      def update
        verified_params(gate_rules) do |attributes|
          if resource.update(attributes)
            render_no_content
          else
            resource_invalid_error(resource)
          end
        end
      end

      private

      def resource
        @resource ||= resources.find(params[:id])
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
