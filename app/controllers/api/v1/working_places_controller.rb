module API
  module V1
    class WorkingPlacesController < ApplicationController

      def show
        render json: WorkingPlaceRepresenter.new(working_place).basic
      end

      def index
        render json: WorkingPlacesRepresenter.new(working_places).basic
      end

      private

      def working_place
        @working_place ||= Account.current.working_places.find(params[:id])
      end

      def working_places
        @working_places ||= Account.current.working_places
      end
    end
  end
end
