module API
  module V1
    class WeeklyReportsController < ApplicationController
      def index
        # render_resource(resources)
        render json: resources, status: :ok
      end

      private

      def resources
        ::WeeklyReports::Index.call(params[:year])
      end

      def resource_representer
        ::Api::V1::WeeklyReportRepresenter
      end
    end
  end
end
