require 'rails_helper'

RSpec.describe WorkingPlace, type: :model do
  include_context 'shared_context_timecop_helper'
  include_context 'shared_context_geoloc_helper'

  shared_examples 'Invalid Address' do
    it { expect(subject.valid?).to eq false }
    it { expect { subject.valid? }.to change { subject.errors.messages[:address] } }
    it { expect(subject.timezone).to be_nil }
  end

  it { is_expected.to have_db_column(:name) }

  it { is_expected.to have_db_column(:country) }
  it { is_expected.to have_db_column(:state) }
  it { is_expected.to have_db_column(:state_code) }
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
    context 'with valid data' do
      context 'with country with state validation' do
        context 'with region passed' do
          subject { create(:working_place, :with_address, state: state_name) }

          it { expect(subject.valid?).to eq true }
          it { expect { subject.valid? }.not_to change { subject.errors.messages[:address] } }
          it { expect(subject.state).to eq('Zurich') }
          it { expect(subject.state_code).to eq('zh') }
        end

        context 'with region not passed' do
          subject { create(:working_place, :with_address) }

          it { expect(subject.valid?).to eq true }
          it { expect { subject.valid? }.not_to change { subject.errors.messages[:address] } }
          it { expect(subject.state).to eq(state_code) }
          it { expect(subject.state_code).to eq(state_code.downcase) }
        end

        context 'with not english country name' do
          subject { create(:working_place, country: 'Suisse', city: 'Genf') }
          let(:state_name) { 'Geneve' }
          let(:state_code) { 'GE' }

          it { expect(subject.valid?).to eq true }
          it { expect { subject.valid? }.not_to change { subject.errors.messages[:address] } }
          it { expect(subject.state).to eq(state_code) }
          it { expect(subject.state_code).to eq('ge') }
        end
      end

      context 'with country without state validation' do
        let(:country) { 'Poland' }
        let(:city) { 'Rzeszow' }
        let(:state_name) { 'Podkarpackie Voivodeship' }
        let(:state_code) { 'Podkarpackie Voivodeship' }
        let(:country_code) { 'PL' }

        %w(Podkarpacie asdf).each do |current_state|
          let(:state) { current_state }

          subject { create(:working_place, country: 'Polska', city: 'Rzeszow', state: state) }

          it { expect(subject.valid?).to eq true }
          it { expect { subject.valid? }.not_to change { subject.errors.messages[:address] } }
          it { expect(subject.state).to eq(state) }
          it { expect(subject.state_code).to eq('podkarpackie voivodeship') }
        end

        context 'without state specified' do
          subject { create(:working_place, country: 'Polska', city: 'Rzeszow', state: nil) }

          it { expect(subject.valid?).to eq true }
          it { expect { subject.valid? }.not_to change { subject.errors.messages[:address] } }
          it { expect(subject.state).to eq('Podkarpackie Voivodeship') }
          it { expect(subject.state_code).to eq('podkarpackie voivodeship') }
        end
      end
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

      context 'with country that has state validation' do
        %w(GE Iowa).each do |current_state|
          let(:state) { current_state }

          subject { build(:working_place, :with_address, state: 'state') }

          it { expect(subject.valid?).to eq false }
          it { expect(subject.timezone).to be_nil }

          it do
            expect { subject.valid? }
              .to change { subject.errors[:state] }
              .to include 'does not match given address'
          end
        end
      end
    end
  end
end
