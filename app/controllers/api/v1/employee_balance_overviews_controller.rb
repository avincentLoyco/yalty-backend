module API
  module V1
    class EmployeeBalanceOverviews < API::ApplicationController
      def show
        authorize! :show, current_user
        render_resource('COLLECTIONS HERE')
      end

      private

      def resource_representer
        ::Api::V1::EmployeeBalanceOverviews
      end
    end
  end
end
