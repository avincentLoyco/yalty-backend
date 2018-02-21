require "rails_helper"

RSpec.describe VerifyEmployeeAttributeValues, type: :service do
  before { Account.current = create(:account) }
  subject { VerifyEmployeeAttributeValues.new(params) }
  let(:boolean_attribute_definition) do
    create(:employee_attribute_definition,
      account: Account.current,
      attribute_type: "Boolean")
  end
  let(:address_definition) do
    create(:employee_attribute_definition,
      account: Account.current,
      attribute_type: "Address")
  end
  let(:monthly_payments_definition) do
    create(:employee_attribute_definition,
      name: "monthly_payments",
      account: Account.current,
      attribute_type: "Number")
  end
  let(:attribute_name) { "lastname" }
  let(:params) do
    {
      attribute_name: attribute_name,
      value: value
    }
  end

  context "when attribute value is valid" do
    context "attribute type and value are strings" do
      let(:value) { "test" }

      it { expect(subject.valid?).to eq true }
      it "should not return error" do
        subject.valid?

        expect(subject.errors.blank?).to eq true
      end
    end

    context "attribute type and value are hashes" do
      let(:attribute_name) { address_definition.name }
      let(:value) {{ city: "Warsaw", country: "Poland" }}

      it { expect(subject.valid?).to eq true }
      it "should not return error" do
        subject.valid?

        expect(subject.errors.blank?).to eq true
      end
    end

    context "attribute type and value are decimals" do
      let(:attribute_name) { "monthly_payments" }
      let(:value) { Faker::Number.decimal(2) }

      it { expect(subject.valid?).to eq true }
      it "should not return error" do
        subject.valid?

        expect(subject.errors.blank?).to eq true
      end
    end

    context "attribute type and value are booleans" do
      let(:attribute_name) { boolean_attribute_definition.name }
      let(:value) { "false" }

      it { expect(subject.valid?).to eq true }
      it "should not return error" do
        subject.valid?

        expect(subject.errors.blank?).to eq true
      end
    end

    context "attribute type and value are dates" do
      let(:attribute_name) { "birthdate" }
      let(:value) { Faker::Date.backward(14).to_s }

      it { expect(subject.valid?).to eq true }
      it "should not return error" do
        subject.valid?

        expect(subject.errors.blank?).to eq true
      end
    end

    context "nil value send" do
      let(:value) { nil }

      it { expect(subject.valid?).to eq true }
      it "should not return error" do
        subject.valid?

        expect(subject.errors.blank?).to eq true
      end
    end

    context "params without attribute name" do
      let(:value) { "test" }
      before { params.delete(:attribute_name) }

      it { expect(subject.valid?).to eq true }
      it "should not return error" do
        subject.valid?

        expect(subject.errors.blank?).to eq true
      end
    end

    context "params without value" do
      let(:value) { "test" }
      before { params.delete(:value) }

      it { expect(subject.valid?).to eq true }
      it "should not return error" do
        subject.valid?

        expect(subject.errors.blank?).to eq true
      end
    end
  end

  context "when attribute value is not valid" do
    context "hash instead of string" do
      let(:value) {{ name: "test" }}

      it { expect(subject.valid?).to eq false }
      it "should return error" do
        subject.valid?

        expect(subject.errors[:value]).to eq(["must be a string"])
      end
    end

    context "string instead of hash send" do
      let(:value) { "test" }
      let(:attribute_name) { address_definition.name }

      it { expect(subject.valid?).to eq false }
      it "should return error" do
        subject.valid?

        expect(subject.errors[:value]).to eq("Invalid type")
      end
    end

    context "array instead of string send" do
      let(:value) { ["a"] }

      it { expect(subject.valid?).to eq false }
      it "should return error" do
        subject.valid?

        expect(subject.errors[:value]).to eq(["must be a string"])
      end
    end

    context "word intead of decimals send" do
      let(:value) { "test" }
      let(:attribute_name) { monthly_payments_definition.name }

      it { expect(subject.valid?).to eq false }
      it "should return error" do
        subject.valid?

        expect(subject.errors[:value]).to eq(["must be a decimal"])
      end
    end

    context "word instead of boolean send" do
      let(:attribute_name) { boolean_attribute_definition.name }
      let(:value) { "test" }

      it { expect(subject.valid?).to eq false }
      it "should not return error" do
        subject.valid?

        expect(subject.errors[:value]).to eq(["must be boolean"])
      end
    end

    context "value has missing params" do
      let(:schema) do
        Dry::Validation.Form do
          required(:foo).filled
        end
      end

      before do
        allow_any_instance_of(Attributes::AddressSchema).to receive(:address_schema)
          .and_return(schema)
      end

      let(:attribute_name) { address_definition.name }
      let(:value) {{ city: "Warsaw", country: "Poland" }}

      it { expect(subject.valid?).to eq false }
      it "should return error" do
        subject.valid?

        expect(subject.errors[:foo]).to eq(["is missing"])
      end
    end
  end
end
