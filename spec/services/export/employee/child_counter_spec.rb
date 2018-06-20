require "rails_helper"

RSpec.describe Export::Employee::ChildCounter, type: :service do
  subject do
    described_class.call(
      children: children,
      attribute: attribute,
      effective_at: effective_at,
      event_type: event_type
    )
  end

  let(:attribute) do
    {
      lastname: "Holmes",
      firstname: "Son",
      birthdate: "2016-06-06",
      gender: "male",
    }
  end

  let(:child) do
    {
      value: attribute,
      effective_at: "",
      event_type: event_type,
    }
  end

  let(:existing_child) do
    {
      value: daughter,
      effective_at: "",
      event_type: event_type,
    }
  end

  let(:daughter) do
    {
      lastname: "Holmes",
      firstname: "Daughter",
      birthdate: "2015-06-06",
      gender: "female",
    }
  end

  let(:children)     { [existing_child] }
  let(:effective_at) { "" }
  let(:event_type)   { "child_birth" }


  context "child birth" do
    context "with no previous children" do
      let(:children) { [] }
      let(:result)   { [child] }

      it { expect(subject).to eq(result) }
    end

    context "with previous child" do
      let(:result) { [existing_child, child] }

      it { expect(subject).to eq(result) }
    end
  end

  context "child adoption" do
    let(:event_type) { "child_adoption"}

    context "with no previous children" do
      let(:children) { [] }
      let(:result)   { [child] }

      it { expect(subject).to eq(result) }
    end

    context "with previous child" do
      let(:result) { [existing_child, child] }

      it { expect(subject).to eq(result) }
    end
  end

  context "child death" do
    context "dead child exist" do
      let(:event_type) { "child_death" }
      let(:children)   { [child] }

      it { expect(subject).to eq([]) }
    end

    context "dead child has no in application record" do
      let(:event_type) { "child_death" }
      let(:children)   { [] }

      it { expect(subject).to eq([]) }
    end
  end
end
