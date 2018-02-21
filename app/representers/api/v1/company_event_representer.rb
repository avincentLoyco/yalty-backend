module Api
  module V1
    class CompanyEventRepresenter < BaseRepresenter
      def complete
        {
          id: resource.id,
          title: resource.title,
          effective_at: resource.effective_at,
          comment: resource.comment,
          files: files_json
        }
      end

      private

      def files_json
        resource.files.map do |file|
          {
            type: "file",
            id: file.id,
            original_filename: file.original_filename
          }
        end
      end
    end
  end
end
