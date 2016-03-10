require 'rails_helper'

RSpec.describe API::V1::CountriesController, type: :controller do
  include_context 'shared_context_headers'

  let(:country_code) { 'ch' }

  describe "GET #show" do
    subject { get :show, id: country_code }

    context 'with valid data' do
      it { is_expected.to have_http_status(200) }

      context 'response body' do
        before { subject }
        it { expect_json_keys([:holidays, :regions]) }


        it 'contains all the regions codes' do
          ISO3166::Country.new(country_code).states.keys.map(&:downcase).each do |region_code|
            expect(response.body).to include region_code
          end
        end

        let(:ch_holidays_codes) do
          [
            "good_friday",
            "easter_monday",
            "ascension_day",
            "whit_monday",
            "corpus_christi",
            "federal_prayday",
            "geneva_prayday",
            "new_years_day",
            "saint_berchtold",
            "epiphany",
            "instauration_republic_neuchatel",
            "saint_joseph",
            "naefelser_fahrt",
            "labour_day",
            "jura_independance_day",
            "sts_peter_and_paul",
            "swiss_national_day",
            "assumption_day",
            "saint_maurice",
            "st_niklaus_von_flue",
            "all_saints_day",
            "immaculate_conception",
            "christmas",
            "st_stephens_day",
            "restoration_republic_geneva"
          ]
        end

        it 'contains all the holidays codes' do
          ch_holidays_codes.each do |holiday_code|
            expect(response.body).to include holiday_code
          end
        end
      end
    end

    context 'invalid data' do
      context 'with invalid country code or not translated codes for the country' do
        let(:country_code) { 'rztd' }

        it { is_expected.to have_http_status(404) }
      end
    end
  end
end
