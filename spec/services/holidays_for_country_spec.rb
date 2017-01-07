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
    context 'with region and filter specified' do
      subject { described_class.new('ch', 'vd', 'upcoming').call }

      it_behaves_like 'Holidays with region specified'

      it 'is filtered to upcoming' do
        response = subject
        expect(response[:holidays].size).to be 10
      end
    end

    context 'with filter and no region specified' do
      subject { described_class.new('ch', nil, 'upcoming').call }

      it_behaves_like 'Holidays without region specified'

      it 'is filtered to upcoming' do
        response = subject
        expect(response[:holidays].size).to be 10
      end
    end

    context 'with region and no filter specified' do
      subject { described_class.new('ch', 'vd', nil).call }

      it_behaves_like 'Holidays with region specified'
    end

    context 'with no region and no filter specified' do
      subject { described_class.new('ch', nil, nil).call }
      it { expect(subject.class).to be Hash }

      it_behaves_like 'Holidays without region specified'

      it 'has proper number of regions' do
        response = subject
        expect(response[:regions].size).to eq(27)
      end
    end

    context 'with nil params' do
      [['pl', 'is', nil], ['ch', 'vp', nil], ['ch', nil, 'incoming']].each do |params|
        subject { described_class.new(params[0], params[1], params[2]).call }
        it { expect { subject }.to raise_error(/Invalid param value/) }
      end
    end
  end
end
