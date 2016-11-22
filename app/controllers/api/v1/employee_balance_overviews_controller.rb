module API
  module V1
    class EmployeeBalanceOverviewsController < API::ApplicationController
      def show
        authorize! :show, current_user

        balances_overview = GenerateBalanceOverview.new(params[:employee_id]).call
        render json: balances_overview
      end

      private

      def resource_representer
        ::Api::V1::EmployeeBalanceOverviews
      end
    end
  end
end
