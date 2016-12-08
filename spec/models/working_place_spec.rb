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
      allow_any_instance_of(WorkingPlace).to receive(:place_timezone) { 'Europe/Zurich' }
    end

    context 'with valid data' do
      subject { create(:working_place, :with_address) }
      before do
        allow_any_instance_of(WorkingPlace).to receive(:place_info) do
          loc = Geokit::GeoLoc.new(city: 'Zürich')
          loc.country = 'Switzerland'
          loc
        end
      end

      it { expect(subject.valid?).to eq true }
      it { expect { subject.valid? }.not_to change { subject.errors.messages[:address] } }
    end

    context 'with invalid data' do
      subject { build(:working_place, :with_address) }
      context 'with invalid city' do
        before do
          allow_any_instance_of(WorkingPlace).to receive(:place_info) do
            Geokit::GeoLoc.new(city: 'asdf')
          end
        end

        it_behaves_like 'Invalid Address'

        context 'should have error message' do
          before { subject.valid? }
          let(:errors) { subject.errors[:address] }

          it { expect(errors).to include 'place not found' }
        end
      end
      context 'with city that does not exist' do
        before { allow_any_instance_of(WorkingPlace).to receive(:place_info) { Geokit::GeoLoc.new } }

        it_behaves_like 'Invalid Address'

        context 'should have error message' do
          before { subject.valid? }
          let(:errors) { subject.errors[:address] }

          it { expect(errors).to include 'place does not exist' }
        end
      end
    end
  end
end
