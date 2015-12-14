module API
  module V1
    class TimeOffsController < ApplicationController
      include TimeOffsRules

      def show
        render_resource(resource)
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

      def destroy
        resource.destroy!
        render_no_content
      end

      private

      def resource
        @resource ||= Account.current.time_offs.find(params[:id])
      end

      def resource_representer
        ::Api::V1::TimeOffsRepresenter
      end
    end
  end
end
