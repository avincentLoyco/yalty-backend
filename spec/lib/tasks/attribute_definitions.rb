require "rails_helper"
require "rake"

RSpec.describe "attribute_definitions:create_missing", type: :rake do
  include_context "rake"

  subject { rake["attribute_definitions:create_missing"].invoke }

  before do
    allow_any_instance_of(Account).to receive(:default_attribute_definition) do
      Account::DEFAULT_ATTRIBUTE_DEFINITIONS
    end
  end

  let(:user) { create :account_user, role: "account_administrator" }
  let(:account) { user.account }
  let(:employee) { create(:employee, account: account) }
  let(:attribute_definitions) { account.employee_attribute_definitions }

  shared_examples "Require Missing" do
    it "creates missing attributes" do
      expect { subject }.to change {
        attribute_definitions.where(system: true).count("DISTINCT attribute_type")
      }.to(Account::DEFAULT_ATTRIBUTES.count)
    end
  end

  shared_examples "Does Not Require Missing" do
    it "doesn't create more attributes" do
      expect { subject }.not_to change {
        attribute_definitions.where(system: true).count("DISTINCT attribute_type")
      }
    end
  end

  context "without custom attributes" do
    context "when some system attributes are missing" do
      before { attribute_definitions.where(attribute_type: "File").delete_all }

      it_behaves_like "Require Missing"
    end

    context "when all system attributes are present" do
      it_behaves_like "Does Not Require Missing"
    end
  end

  context "with custom attributes" do
    before { attribute_definitions.create(name: "asdf", attribute_type: "String") }

    context "when some system attributes are missing" do
      before { attribute_definitions.where(attribute_type: "File").delete_all }

      it_behaves_like "Require Missing"
    end

    context "when all system attributes are present" do
      it_behaves_like "Does Not Require Missing"
    end
  end
end
