require "rails_helper"

RSpec.describe AbilityFactory do
  let_it_be(:account) { build(:account) }
  describe ".build_for" do
    subject { described_class.build_for(user) }

    let(:user) { build(:account_user, role: role, account: account) }

    context "when normal user" do
      let(:role) { :user }

      it { is_expected.to be_a AbilityUser }
    end

    context "when account owner" do
      let(:role) { :account_owner }

      it { is_expected.to be_a AbilityAccountOwner }
    end

    context "when account administrator" do
      let(:role) { :account_administrator }

      it { is_expected.to be_a AbilityAccountAdministrator }
    end

    context "when anonymous" do
      let(:user) { nil }

      it { is_expected.to be_a Ability }
    end

    context "when unknown role" do
      let(:role) { :unknown }

      it "raises a not found error" do
        expect { subject }.to raise_error AbilityFactory::UnknownRoleError
      end
    end
  end
end
