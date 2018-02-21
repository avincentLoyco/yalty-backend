require "rails_helper"

RSpec.describe WorkingPlace, type: :model do
  include_context "shared_context_timecop_helper"
  include_context "shared_context_geoloc_helper"

  shared_examples "Invalid Address" do
    it { expect(subject).to_not be_valid }
    it { expect(subject.errors).to have_key(:address) }
    it { expect(subject.errors[:address]).to include("not found") }
  end

  it { is_expected.to have_db_column(:name) }

  it { is_expected.to have_db_column(:country) }
  it { is_expected.to have_db_column(:country_code) }
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

  it { is_expected.to validate_length_of(:country_code).is_at_most(60) }
  it { is_expected.to validate_length_of(:city).is_at_most(60) }
  it { is_expected.to validate_length_of(:state_code).is_at_most(60) }
  it { is_expected.to validate_length_of(:postalcode).is_at_most(12) }
  it { is_expected.to validate_length_of(:street).is_at_most(72) }
  it { is_expected.to validate_length_of(:street_number).is_at_most(10) }
  it { is_expected.to validate_length_of(:additional_address).is_at_most(60) }

  it { is_expected.to belong_to(:holiday_policy) }

  context "address and timezone" do
    before { subject.validate }

    context "with valid data" do
      let(:city) { "Zurich" }
      let(:state_name) { "Zurich" }
      let(:state_code) { "ZH" }
      let(:country) { "Switzerland" }
      let(:country_code) { "CH" }
      let(:timezone) { "Europe/Zurich" }

      context "for a country with state validation" do
        context "create with city, state code and country code" do
          subject { build(:working_place, city: city, state_code: state_code, country_code: country_code) }

          it { expect(subject).to be_valid }
          it { expect(subject.state).to eq("Zurich") }
          it { expect(subject.state_code).to eq("ZH") }
          it { expect(subject.country).to eq("Switzerland") }
          it { expect(subject.country_code).to eq("CH") }
          it { expect(subject.timezone).to eql("Europe/Zurich") }
        end

        context "create with city and country code" do
          subject { build(:working_place, city: city, country_code: country_code) }

          it { expect(subject).to be_valid }
          it { expect(subject.state).to eq("Zurich") }
          it { expect(subject.state_code).to eq("ZH") }
          it { expect(subject.country).to eq("Switzerland") }
          it { expect(subject.country_code).to eq("CH") }
          it { expect(subject.timezone).to eql("Europe/Zurich") }
        end

        context "create with state code and country code" do
          subject { build(:working_place, state_code: "ZH", country_code: country_code) }

          let(:city) { nil }
          let(:state_code) { state_name }

          it { expect(subject).to be_valid }
          it { expect(subject.state).to eq("Zurich") }
          it { expect(subject.state_code).to eq("ZH") }
          it { expect(subject.country).to eq("Switzerland") }
          it { expect(subject.country_code).to eq("CH") }
          it { expect(subject.timezone).to eql("Europe/Zurich") }
        end


        context "create with non english city name" do
          subject { build(:working_place, city: "Genf", country_code: country_code) }
          let(:city) { "Geneva" }
          let(:state_name) { "Geneva" }
          let(:state_code) { "GE" }

          it { expect(subject).to be_valid }
          it { expect(subject.state).to eq("Geneva") }
          it { expect(subject.state_code).to eq("GE") }
          it { expect(subject.country).to eq("Switzerland") }
          it { expect(subject.country_code).to eq("CH") }
          it { expect(subject.timezone).to eql("Europe/Zurich") }
        end

        context "create with city that have same name as the state" do
          subject { build(:working_place, city: "Zug", state_code: state_code, country_code: country_code) }
          let(:city) { nil }
          let(:state_name) { "Canton of Zug" }
          let(:state_code) { "ZG" }

          it { expect(subject).to be_valid }
          it { expect(subject.state).to eq("Canton of Zug") }
          it { expect(subject.state_code).to eq("ZG") }
          it { expect(subject.country).to eq("Switzerland") }
          it { expect(subject.country_code).to eq("CH") }
          it { expect(subject.timezone).to eql("Europe/Zurich") }
        end

        context "update city code and state code" do
          subject { create(:working_place, city: city, state_code: state_code, country_code: country_code) }

          before do
            allow(subject).to receive(:location_attributes) do
              geoloc_instance(
                city: "Geneva",
                state_name: "Geneva",
                state_code: "GE",
                country: "Switzerland",
                country_code: "CH",
              )
            end

            subject.city = "Geneva"
            subject.state_code = "GE"
            subject.validate
          end

          it { expect(subject).to be_valid }
          it { expect(subject.city).to eq("Geneva") }
          it { expect(subject.state).to eq("Geneva") }
          it { expect(subject.state_code).to eq("GE") }
          it { expect(subject.country).to eq("Switzerland") }
          it { expect(subject.country_code).to eq("CH") }
          it { expect(subject.timezone).to eql("Europe/Zurich") }
        end

        context "update state when city is empty" do
          subject { create(:working_place, state_code: "ZH", country_code: country_code) }

          let(:city) { nil }
          let(:state_code) { state_name }

          before do
            allow(subject).to receive(:location_attributes) do
              geoloc_instance(
                city: nil,
                state_name: "Geneva",
                state_code: "Geneva",
                country: "Switzerland",
                country_code: "CH",
              )
            end

            subject.state_code = "GE"
            subject.validate
          end

          it { expect(subject).to be_valid }
          it { expect(subject.state).to eq("Geneva") }
          it { expect(subject.state_code).to eq("GE") }
          it { expect(subject.country).to eq("Switzerland") }
          it { expect(subject.country_code).to eq("CH") }
          it { expect(subject.timezone).to eql("Europe/Zurich") }
        end

        context "update city when previously empty" do
          subject { create(:working_place, state_code: state_code, country_code: country_code) }

          let(:city) { nil }

          before do
            allow(subject).to receive(:location_attributes) do
              geoloc_instance(
                city: "Zurich",
                state_name: state_name,
                state_code: state_code,
                country: country,
                country_code: country_code,
              )
            end

            subject.city = "Zurich"
            subject.validate
          end

          it { expect(subject).to be_valid }
          it { expect(subject.city).to eq("Zurich") }
          it { expect(subject.state).to eq("Zurich") }
          it { expect(subject.state_code).to eq("ZH") }
          it { expect(subject.country).to eq("Switzerland") }
          it { expect(subject.country_code).to eq("CH") }
          it { expect(subject.timezone).to eql("Europe/Zurich") }
        end

        context "update city and set empty state code" do
          subject { create(:working_place, city: city, state_code: state_code, country_code: country_code) }

          before do
            allow(subject).to receive(:location_attributes) do
              geoloc_instance(
                city: "Geneva",
                state_name: "Geneva",
                state_code: "GE",
                country: "Switzerland",
                country_code: "CH",
              )
            end

            subject.city = "Geneva"
            subject.state_code = nil
            subject.validate
          end

          it { expect(subject).to be_valid }
          it { expect(subject.city).to eq("Geneva") }
          it { expect(subject.state).to eq("Geneva") }
          it { expect(subject.state_code).to eq("GE") }
          it { expect(subject.timezone).to eql("Europe/Zurich") }
        end

        context "update address to empty" do
          subject { create(:working_place, city: city, state_code: state_code, country_code: country_code) }

          before do
            allow(subject).to receive(:location_attributes) do
              geoloc_instance(
                city: nil,
                state_name: nil,
                state_code: nil,
                country: nil,
                country_code: nil,
              )
            end

            subject.city = nil
            subject.state_code = nil
            subject.country_code = nil
            subject.validate
          end

          it { expect(subject).to be_valid }
          it { expect(subject.city).to eq(nil) }
          it { expect(subject.state).to eq(nil) }
          it { expect(subject.state_code).to eq(nil) }
          it { expect(subject.country).to eq(nil) }
          it { expect(subject.country_code).to eq(nil) }
          it { expect(subject.timezone).to eql(nil) }
        end

        context "update anything else coordinate" do
          subject { spy(working_place) }

          let!(:working_place) { create(:working_place, city: city, country_code: country_code) }

          before do
            subject.name = "New office"
            subject.validate
          end

          it { expect(subject).to be_valid }
          it { expect(subject).to_not have_received(:location_attributes) }
          it { expect(subject).to_not have_received(:location_timezone) }
        end
      end

      context "with country without state validation" do
        let(:city) { "Rzeszow" }
        let(:state_name) { "Podkarpackie Voivodeship" }
        let(:state_code) { "Podkarpackie Voivodeship" }
        let(:country) { "Poland" }
        let(:country_code) { "PL" }
        let(:timezone) { "Europe/Warsaw" }

        context "create with city" do
          subject { build(:working_place, city: city, state_code: state_code, country_code: country_code) }

          it { expect(subject).to be_valid }
          it { expect(subject.errors).to_not have_key(:address) }
          it { expect(subject.state).to eq("Podkarpackie Voivodeship") }
          it { expect(subject.state_code).to eql("Podkarpackie Voivodeship") }
          it { expect(subject.country).to eq("Poland") }
          it { expect(subject.country_code).to eq("PL") }
          it { expect(subject.timezone).to eql("Europe/Warsaw") }
        end
      end
    end

    context "with invalid data" do
      let(:city) { nil }
      let(:country) { nil }
      let(:country_code) { nil }
      let(:state_name) { nil }
      let(:state_code) { nil }

      context "create with country that dosen't exist" do
        subject { build(:working_place, city: "Zurich", country_code: "NotACountry") }

        it_behaves_like "Invalid Address"

        it { expect(subject.errors).to_not have_key(:state_code) }
        it { expect(subject.errors).to have_key(:country_code) }
        it { expect(subject.errors[:country_code]).to include("does not exist") }

        it { expect(subject.state).to be_nil }
        it { expect(subject.state_code).to be_nil }
        it { expect(subject.country).to be_nil }
        it { expect(subject.timezone).to be_nil }
      end

      context "create without city and state code" do
        subject { build(:working_place, country_code: "CH") }

        let(:country) { "Switzerland" }
        let(:country_code) { "CH" }

        it_behaves_like "Invalid Address"

        it { expect(subject.errors).to_not have_key(:state_code) }
        it { expect(subject.errors).to_not have_key(:country_code) }

        it { expect(subject.state).to be_nil }
        it { expect(subject.state_code).to be_nil }
        it { expect(subject.country).to be_nil }
        it { expect(subject.timezone).to be_nil }
      end

      context "create with city only" do
        subject { build(:working_place, city: "Lausanne") }

        let(:city) { "Lausanne" }
        let(:state) { "Vaud" }
        let(:state_code) { "VD" }
        let(:country) { "Switzerland" }
        let(:country_code) { "CH" }
        let(:timezone) { "Europe/Zurich" }

        it_behaves_like "Invalid Address"

        it { expect(subject.errors).to_not have_key(:state_code) }
        it { expect(subject.errors).to_not have_key(:country_code) }

        it { expect(subject.state).to be_nil }
        it { expect(subject.state_code).to be_nil }
        it { expect(subject.country).to be_nil }
        it { expect(subject.country_code).to be_nil }
        it { expect(subject.timezone).to be_nil }
      end

      context "create with city that dosen't exist" do
        subject { build(:working_place, city: "NotACity", country_code: "CH") }

        it_behaves_like "Invalid Address"

        it { expect(subject.errors).to_not have_key(:state_code) }
        it { expect(subject.errors).to_not have_key(:country_code) }

        it { expect(subject.state).to be_nil }
        it { expect(subject.state_code).to be_nil }
        it { expect(subject.country).to be_nil }
        it { expect(subject.timezone).to be_nil }
      end

      context "create with city that dosen't exist in country" do
        subject { build(:working_place, city: "Paris", country_code: "CH") }

        let(:city) { "Paris" }
        let(:country) { "France" }
        let(:country_code) { "FR" }
        let(:state_name) { "Île-de-France" }
        let(:state_code) { "Île-de-France" }
        let(:timezone) { "Paris/Europe" }

        it_behaves_like "Invalid Address"

        it { expect(subject.errors).to_not have_key(:state_code) }
        it { expect(subject.errors).to_not have_key(:country_code) }

        it { expect(subject.state).to be_nil }
        it { expect(subject.state_code).to be_nil }
        it { expect(subject.country).to be_nil }
        it { expect(subject.timezone).to be_nil }
      end

      context "with country that has state validation" do
        context "create with state that doesn't exist" do
          subject { build(:working_place, city: city, state_code: "Wrong", country_code: country_code) }

          let(:city) { "Zurich" }
          let(:country) { "Switzerland" }
          let(:country_code) { "CH" }
          let(:state_name) { "Zurich" }
          let(:state_code) { "ZH" }
          let(:timezone) { "Zurich/Europe" }

          it { expect(subject).to_not be_valid }

          it { expect(subject.errors).to_not have_key(:address) }
          it { expect(subject.errors).to have_key(:state_code) }
          it { expect(subject.errors[:state_code]).to include("does not match given address") }
          it { expect(subject.errors).to_not have_key(:country_code) }

          it { expect(subject.state).to be_nil }
          it { expect(subject.state_code).to eql("Wrong") }
          it { expect(subject.country).to be_nil }
          it { expect(subject.country_code).to eql("CH") }
          it { expect(subject.timezone).to be_nil }
        end
      end
    end
  end
end
