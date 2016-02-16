module API
  module V1
    class CountriesController < API::ApplicationController
      def show
        authorize! :show, current_user
        fail ActiveRecord::RecordNotFound unless country_has_codes_for_holidays
        render_resource(params[:id])
      end

      private

      def resource_representer
        ::Api::V1::CountryRepresenter
      end

      def country_has_codes_for_holidays
        HolidaysCodeName::COUNTRIES_WITH_CODES.include?(params[:id])
      end
    end
  end
end
