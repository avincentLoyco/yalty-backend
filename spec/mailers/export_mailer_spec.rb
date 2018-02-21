require "rails_helper"

RSpec.describe ExportMailer, type: :mailer do
  let(:account)        { create(:account) }

  let!(:owners)        { create_list(:account_user, 2, account: account, role: "account_owner") }
  let!(:administrator) { create(:account_user, account: account, role: "account_administrator") }
  let!(:user)          { create(:account_user, account: account, role: "user") }

  context "#archive_generation" do
    subject(:mailer) { ExportMailer.archive_generation(account).deliver_now }

    it { expect { mailer }.to change { ActionMailer::Base.deliveries.count } }

    it do
      expect(mailer.subject).to eq("#{account.company_name}: Your archive is ready to download!")
    end

    it { expect(mailer.body.to_s).to match(/ready/) }
    it { expect(mailer.body.to_s).to match(/View Archive/) }

    context "only account owners receive mail" do
      it { expect(mailer.to).to match_array([owners.first.email, owners.second.email]) }
      it { expect(mailer.to).not_to include(administrator.email, user.email) }
    end
  end
end
