module API
  module V1
    class TimeOffCategoriesController < ApplicationController
      def show
        render_resource(resource)
      end

      def index
        render_resource(resources)
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
