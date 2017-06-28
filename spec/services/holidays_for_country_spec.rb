require 'rails_helper'

RSpec.describe HolidaysForCountry, type: :service do
  include_context 'shared_context_timecop_helper'

  shared_examples 'Holidays without region specified' do
    it 'returns the holidays of a country and the regions with the holidays for each region' do
      result = subject
      expect(result[:holidays].class).to be Array
      expect(result[:holidays].first).to include :code, :date
      expect(result[:regions].class).to be Array
      expect(result[:regions].first).to include :code, :holidays
      result[:regions].each do |region_hash|
        expect(region_hash[:code]).to_not equal :at
      end
    end
  end

  shared_examples 'Holidays with region specified' do
    it 'returns the holidays of a country' do
      result = subject
      expect(result[:holidays].class).to be Array
      expect(result[:holidays].first).to include :code, :date
    end
  end

  describe '#call' do
    let(:country) { 'ch' }
    subject { described_class.new(country, region, filter).call }
    context 'with region' do
      let(:region) { 'vd' }

      context 'when filter is specified' do
        let(:filter) { 'upcoming' }

        it_behaves_like 'Holidays with region specified'

        it 'is filtered to upcoming' do
          expect(subject[:holidays].size).to eq(10)
        end
      end

      context 'when filter is not specified' do
        let(:filter) { nil }

        it_behaves_like 'Holidays with region specified'
      end
    end

    context 'with no region' do
      let(:region) { nil }

      context 'when filter is specified' do
        let(:filter) { 'upcoming' }

        it_behaves_like 'Holidays without region specified'

        it 'is filtered to upcoming' do
          expect(subject[:holidays].size).to eq(10)
        end
      end

      context 'when filter is not specified' do
        let(:filter) { nil }

        it { expect(subject.class).to be Hash }

        it_behaves_like 'Holidays without region specified'

        it 'has proper number of regions' do
          expect(subject[:regions].size).to eq(27)
        end
      end
    end

    context 'with invalid params' do
      let(:country) { 'ch' }
      let(:region) { 'vp' }
      let(:filter) { 'upcoming' }
      context 'with region param given for a country without regions' do
        let(:country) { 'pl' }

        it { expect { subject }.to raise_error(API::V1::Exceptions::CustomError) }
      end

      context 'with invalid region' do
        let(:region) { 'vp' }

        it { expect { subject }.to raise_error(API::V1::Exceptions::CustomError) }
      end

      context 'with invalid filter' do
        let(:filter) { 'incoming' }

        it { expect { subject }.to raise_error(API::V1::Exceptions::CustomError) }
      end
    end
  end
end
