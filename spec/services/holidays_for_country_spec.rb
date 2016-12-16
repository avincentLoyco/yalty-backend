require 'rails_helper'

RSpec.describe HolidaysForCountry, type: :service do
  include_context 'shared_context_timecop_helper'

  shared_examples 'Holidays without region specified' do
    it 'returns the holidays of a country and the regions with the holidays for each region' do
      holidays, regions_with_holidays = subject
      expect(holidays.class).to be Array
      expect(holidays.first).to include :code, :date
      expect(regions_with_holidays.class).to be Array
      expect(regions_with_holidays.first).to include :code, :holidays
      regions_with_holidays.each do |region_hash|
        expect(region_hash[:code]).to_not equal :at
      end
    end
  end

  shared_examples 'Holidays with region specified' do
    it 'returns the holidays of a country' do
      holidays = subject
      expect(holidays.class).to be Array
      expect(holidays.first).to include :code, :date
    end
  end

  describe '#call' do
    context 'with region and filter specified' do
      subject { described_class.new('ch', true, region: 'vd', filter: 'upcoming').call }

      it_behaves_like 'Holidays with region specified'

      it 'is filtered to upcoming' do
        holidays = subject
        expect(holidays.size).to be 10
      end
    end

    context 'with filter and no region specified' do
      subject { described_class.new('ch', true, filter: 'upcoming').call }

      it_behaves_like 'Holidays without region specified'

      it 'is filtered to upcoming' do
        holidays, regions_with_holidays = subject
        expect(holidays.size).to be 10
      end
    end

    context 'with region and no filter specified' do
      subject { described_class.new('ch', true, region: 'vd').call }

      it_behaves_like 'Holidays with region specified'
    end

    context 'with no region and no filter specified' do
      subject { described_class.new('ch', true).call }
      it { expect(subject.class).to be Array }

      it_behaves_like 'Holidays without region specified'

      it 'has proper number of regions' do
        holidays, regions_with_holidays = subject
        expect(regions_with_holidays.size).to eq(27)
      end
    end

    context 'when region is specified for country that has no regions' do
      subject { described_class.new('pl', false, region: 'is').call }
      it { expect { subject }.to raise_error(/Country doesn't have regions/) }
    end

    context 'when region is not valid' do
      subject { described_class.new('ch', true, region: 'vp').call }
      it { expect { subject }.to raise_error(/Region doesn't exist/) }
    end

    context 'when filter is not valid' do
      subject { described_class.new('ch', true, filter: 'incoming').call }
      it { expect { subject }.to raise_error(/Wrong type of filter specified/) }
    end
  end
end
