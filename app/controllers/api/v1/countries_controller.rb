module API
  module V1
    class CountriesController < API::ApplicationController
      def show
        authorize! :show, current_user
        raise ActiveRecord::RecordNotFound unless country_has_codes_for_holidays
        render_holidays
      end

      private

      def render_holidays
        holidays = HolidaysForCountry.new(params[:id], params[:region], params[:filter]).call
        render json: resource_representer.new(holidays[:holidays], holidays[:regions]).complete
      end

      def country_without_regions?
        HolidayPolicy::COUNTRIES_WITHOUT_REGIONS.include?(params[:id])
      end

      def resource_representer
        ::Api::V1::CountryRepresenter
      end

      def country_has_codes_for_holidays
        (HolidayPolicy::COUNTRIES_WITH_CODES + HolidayPolicy::COUNTRIES_WITHOUT_REGIONS)
          .include?(params[:id])
      end
    end
  end
end
