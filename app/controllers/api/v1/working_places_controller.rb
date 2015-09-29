module API
  module V1
    class WorkingPlacesController < JSONAPI::ResourceController

      private

      def setup_request(account_id = Account.current.try(:id).to_s)
        if params['action'] == 'create'
          new_params = params.deep_merge(data: {attributes: {"account-id": account_id}})
        end
        @request = JSONAPI::Request.new(new_params || params, context: context, key_formatter: key_formatter)

        render_errors(@request.errors) unless @request.errors.empty?
      rescue => e
        handle_exceptions(e)
      end
    end
  end
end
