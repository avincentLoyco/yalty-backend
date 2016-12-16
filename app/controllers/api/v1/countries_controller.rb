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
        if params[:region].present? || !regions?
          holidays = HolidaysForCountry.new(params[:id], regions?, params_hash).call
          render json: resource_representer.new(holidays).only_holidays
        else
          holidays, regions = HolidaysForCountry.new(params[:id], regions?, params_hash).call
          render json: resource_representer.new(holidays, regions).complete
        end
      end

      def regions?
        !HolidayPolicy::COUNTRIES_WITHOUT_REGIONS.include?(params[:id])
      end

      def params_hash
        params_hash = {}
        params_hash[:region] = params[:region] if params[:region].present?
        params_hash[:filter] = params[:filter] if params[:filter].present?
        params_hash
      end

      def resource_representer
        ::Api::V1::CountryRepresenter
      end

      def country_has_codes_for_holidays
        countries_codes = HolidayPolicy::COUNTRIES_WITH_CODES +
          HolidayPolicy::COUNTRIES_WITHOUT_REGIONS
        countries_codes.include?(params[:id])
      end
    end
  end
end
