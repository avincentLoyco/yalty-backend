module API
  module V1
    class SettingsController < JSONAPI::ResourceController
      private

      def setup_request(id = Account.current.try(:id).to_s)
        new_params = params.merge(id: id).deep_merge(data: {id: id})
        @request = JSONAPI::Request.new(
          new_params,
          context: context,
          key_formatter: key_formatter
        )

        render_errors(@request.errors) unless @request.errors.empty?
      rescue => e
        handle_exceptions(e)
      end
    end
  end
end
