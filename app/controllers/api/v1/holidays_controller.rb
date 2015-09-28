module API
  module V1
    class HolidaysController < JSONAPI::ResourceController

    private

    def setup_request
        new_params = params.deep_merge(data: { attributes: { "holiday-policy-id" => params[:holiday_policy_id] }})
        @request = JSONAPI::Request.new(new_params, context: context, key_formatter: key_formatter)

        render_errors(@request.errors) unless @request.errors.empty?
      rescue => e
        handle_exceptions(e)
      end
    end
  end
end
