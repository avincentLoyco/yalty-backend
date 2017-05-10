module API
  module V1
    class ExportsController < ApplicationController
      def create
        Account.current.update!(archive_processing: true)
        ::Export::ScheduleArchiveProcess.perform_later(Account.current)
        render_json_response
      end

      def show
        render_json_response
      end

      private

      def render_json_response
        render json: export_representer.complete, status: export_representer.status_code
      end

      def export_representer
        @export_representer ||= ::Api::V1::ExportRepresenter.new(Account.current)
      end
    end
  end
end
