require 'rails_helper'

RSpec.describe WorkingPlace, type: :model do
  include_context 'shared_context_timecop_helper'

  shared_examples 'Invalid Address' do
    it { expect(subject.valid?).to eq false }
    it { expect { subject.valid? }.to change { subject.errors.messages[:address] } }
    it { expect(subject.timezone).to be_nil }
  end

  it { is_expected.to have_db_column(:name) }

  it { is_expected.to have_db_column(:country) }
  it { is_expected.to have_db_column(:state) }
  it { is_expected.to have_db_column(:city) }
  it { is_expected.to have_db_column(:postalcode) }
  it { is_expected.to have_db_column(:street_number) }
  it { is_expected.to have_db_column(:street) }
  it { is_expected.to have_db_column(:additional_address) }
  it { is_expected.to have_db_column(:timezone) }

  it { is_expected.to have_many(:employees) }
  it { is_expected.to have_many(:employee_working_places) }
  it { is_expected.to respond_to(:employees) }

  it { is_expected.to have_db_column(:account_id).of_type(:uuid) }
  it { is_expected.to belong_to(:account).inverse_of(:working_places) }
  it { is_expected.to respond_to(:account) }

  it { is_expected.to validate_presence_of(:account) }

  it { is_expected.to validate_length_of(:country).is_at_most(60) }
  it { is_expected.to validate_length_of(:city).is_at_most(60) }
  it { is_expected.to validate_length_of(:state).is_at_most(60) }
  it { is_expected.to validate_length_of(:postalcode).is_at_most(12) }
  it { is_expected.to validate_length_of(:street).is_at_most(72) }
  it { is_expected.to validate_length_of(:street_number).is_at_most(10) }
  it { is_expected.to validate_length_of(:additional_address).is_at_most(60) }

  it { is_expected.to belong_to(:holiday_policy) }

  context 'address and timezone' do
    before do
      allow_any_instance_of(WorkingPlace).to receive(:location_attributes) { place_info_result }
      allow_any_instance_of(WorkingPlace).to receive(:location_timezone) { 'Europe/Zurich' }
    end

    let(:city) { 'Zurich' }
    let(:country) { 'Switzerland' }

    let(:place_info_result) do
      loc = Geokit::GeoLoc.new(city: city)
      loc.country = country
      loc.country_code = 'CH'
      loc.state_code = 'ZH'
      loc
    end

    context 'with valid data' do
      subject { create(:working_place, :with_address) }

      it { expect(subject.valid?).to eq true }
      it { expect { subject.valid? }.not_to change { subject.errors.messages[:address] } }
    end

    context 'with not english country names' do
      subject { create(:working_place, country: 'Suisse', city: 'Genf') }

      it { expect(subject.valid?).to eq true }
      it { expect { subject.valid? }.not_to change { subject.errors.messages[:address] } }
    end

    context 'with invalid data' do
      subject { build(:working_place, :with_address) }

      context "with country that dosen't exist" do
        subject { build(:working_place, country: 'asdf', city: 'asdf') }
        let(:country) { nil }

        it_behaves_like 'Invalid Address'

        it do
          expect { subject.valid? }
            .to change { subject.errors[:country] }
            .to include 'does not exist'
        end
        it do
          expect { subject.valid? }.to change { subject.errors[:address] }.to include 'not found'
        end
      end

      context 'with invalid country' do
        let(:city) { 'asdf' }
        let(:country) { 'asdf' }

        it_behaves_like 'Invalid Address'

        it do
          expect { subject.valid? }.to change { subject.errors[:address] }.to include 'not found'
        end
      end

      context 'with invalid city' do
        let(:city) { 'asdf' }
        let(:country) { nil }

        it_behaves_like 'Invalid Address'

        it do
          expect { subject.valid? }.to change { subject.errors[:address] }.to include 'not found'
        end
      end

      context 'with city that does not exist' do
        let(:city) { nil }

        it_behaves_like 'Invalid Address'

        it do
          expect { subject.valid? }.to change { subject.errors[:address] }.to include 'not found'
        end
      end
    end
  end
end
