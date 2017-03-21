require 'rails_helper'

RSpec.describe API::V1::CountriesController, type: :controller do
  include_context 'shared_context_headers'

  let(:country_code) { 'ch' }
  let(:region) { nil }
  let(:filter) { nil }

  describe "GET #show" do
    subject { get :show, id: country_code, region: region, filter: filter }
    context 'with only country specified' do

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
            beginning_of_year = Time.zone.now.beginning_of_year
            end_of_year = Time.zone.now.end_of_year

            Holidays.between(beginning_of_year, end_of_year, 'ch_').map { |holiday| holiday[:name] }
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

    context 'with region specified' do
      let(:region) { 'vd' }

      context 'with valid data' do
        it { is_expected.to have_http_status(200) }

        context 'response body' do
          before { subject }
          it { expect_json_keys(:holidays) }
        end
      end

      context 'with invalid data' do
        let(:region) { 'rztd' }

        it { is_expected.to have_http_status(422) }
      end
    end

    context 'with filter specified' do
      let(:filter) { 'upcoming' }

      context 'with valid data' do
        it { is_expected.to have_http_status(200) }

        context 'response body' do
          before { subject }
          it { expect_json_keys([:holidays, :regions]) }

          it { expect_json(holidays: ->(holidays) { expect(holidays.size).to eq(10) }) }
        end
      end

      context 'with invalid data' do
        let(:filter) { 'incoming' }

        it { is_expected.to have_http_status(422) }
      end
    end

    context 'with region and filter specified' do
      let(:region) { 'ju' }
      let(:filter) { 'upcoming' }

      context 'with valid data' do
        it { is_expected.to have_http_status(200) }

        context 'response body' do
          before { subject }
          it { expect_json_keys(:holidays) }

          it { expect_json(holidays: ->(holidays) { expect(holidays.size).to eq(10) }) }
        end
      end

      context 'with invalid region' do
        let(:region) { 'rztd' }

        it { is_expected.to have_http_status(422) }
      end

      context 'with invalid filter' do
        let(:filter) { 'incoming' }

        it { is_expected.to have_http_status(422) }
      end
    end
  end
end
