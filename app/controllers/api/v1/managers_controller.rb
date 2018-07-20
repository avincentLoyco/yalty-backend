module API
  module V1
    class ManagersController < ApplicationController
      def index
        render json: resources.map { |item| representer.new(item.employee).fullname }
      end

      def show
        render json: representer.new(resource).fullname
      end

      private

      def resource
        Account.current.employees.find_by(account_user_id: params[:id])
      end

      def resources
        Account.current.managers.includes(:employee)
      end

      def representer
        Api::V1::EmployeeRepresenter
      end
    end
  end
end
