module Api
  module V1
    class ExportRepresenter < BaseRepresenter
      def initialize(account)
        @account = account
      end

      def complete
        {
          status: archive_status,
          file_id: file_id,
          archive_date: archive_date
        }
      end

      def status_code
        @account.archive_processing ? 202 : 200
      end

      private

      def archive_date
        @account.archive_file&.created_at if archive_status.eql?("complete")
      end

      def file_id
        @account.archive_file&.id if archive_status.eql?("complete")
      end

      def archive_status
        @archive_status ||= @account.archive_processing ? "processing" : "complete"
      end
    end
  end
end
