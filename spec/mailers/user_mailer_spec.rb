require "rails_helper"

RSpec.describe UserMailer, type: :mailer do
  let(:user) { create(:account_user, :with_reset_password_token) }

  context "#account_creation_confirmation" do
    let(:password) { "12345678" }

    subject { UserMailer.account_creation_confirmation(user.id).deliver_now }

    it { expect { subject }.to change { ActionMailer::Base.deliveries.count } }
    it "email should contain proper password and url" do
      expect(subject.body.to_s).to match(/https?:\/\/#{user.account.subdomain}/)
    end
  end

  context "#user_invitation" do
    let(:login_url) { "http://#{user.account.subdomain}.yaltyapp.com/?code=12345678" }

    subject { UserMailer.user_invitation(user.id, login_url).deliver_now }

    it { expect { subject }.to change { ActionMailer::Base.deliveries.count } }
    it "email should contain proper password and url" do
      expect(subject.body.to_s).to match(/https?:\/\/#{user.account.subdomain}.+code=12345678/)
    end
  end

  context "#accounts_list" do
    let(:account) { user.account }
    let(:second_account) { create(:account_user, email: user.email).account }

    let(:email) { user.email }
    let(:account_ids) { [account.id, second_account.id] }

    subject { UserMailer.accounts_list(email, account_ids).deliver_now }

    it { expect { subject }.to change { ActionMailer::Base.deliveries.count } }
    it "email should contain proper subdomains" do
      expect(subject.body.to_s).to include(account.subdomain)
      expect(subject.body.to_s).to include(second_account.subdomain)
    end
  end

  context "#reset_password" do
    subject { UserMailer.reset_password(user.id).deliver_now }

    it { expect { subject }.to change { ActionMailer::Base.deliveries.count } }
    it "email should contain proper password and url" do
      expect(subject.body.to_s).to include(user.reset_password_token)
    end
  end
end
