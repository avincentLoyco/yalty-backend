require 'rails_helper'

RSpec.describe HolidaysForCountry, type: :service do
  subject{ described_class.new('ch').call }

  describe '#call' do
    it { expect(subject.class).to be Array }
    it 'returns the holidays of a country and the regions with the holidays for each region' do |variable|
        holidays , regions_with_holidays = subject
        expect(holidays.class).to be Array
        expect(holidays.first).to include :code, :date
        expect(regions_with_holidays.class).to be Array
        expect(regions_with_holidays.first).to include :code, :holidays
    end
  end

end
