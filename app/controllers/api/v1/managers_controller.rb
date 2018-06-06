module API
  module V1
    class ManagersController < ApplicationController
      def index
        render json: resources.map { |item| representer.new(item.employee).dropdown }
      end

      private

      def resources
        Account.current.managers.includes(:employee)
      end

      def representer
        Api::V1::EmployeeRepresenter
      end
    end
  end
end
