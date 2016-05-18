require "rails_helper"

RSpec.describe UserMailer, type: :mailer do
  let(:user) { create(:account_user, :with_reset_password_token) }

  context '#account_creation_confirmation' do
    let(:password) { '12345678' }

    subject { UserMailer.account_creation_confirmation(user.id, password).deliver_now }

    it { expect { subject }.to change { ActionMailer::Base.deliveries.count } }
    it 'email should contain proper password and url' do
      expect(subject.body.to_s).to include(password)
      expect(subject.body.to_s).to include(user.account.subdomain)
    end
  end

  context '#credentials' do
    let(:password) { '12345678' }
    let(:url) { Faker::Internet.url }

    subject { UserMailer.credentials(user.id, password, url).deliver_now }

    it { expect { subject }.to change { ActionMailer::Base.deliveries.count } }
    it 'email should contain proper password and url' do
      email = subject
      expect(email.body.to_s).to include(password)
      expect(email.body.to_s).to include(url)
    end
  end

  context '#accounts_list' do
    let(:email) { Faker::Internet.email }
    let(:subdomains_list) { ['abc', 'cba'] }

    subject { UserMailer.accounts_list(email, subdomains_list).deliver_now }

    it { expect { subject }.to change { ActionMailer::Base.deliveries.count } }
    it 'email should contain proper subdomains' do
      email = subject
      expect(email.body.to_s).to include(subdomains_list.first)
      expect(email.body.to_s).to include(subdomains_list.last)
    end
  end

  context '#reset_password' do
    let(:url) { user.account.subdomain + '.test?reset_password_token=' + user.reset_password_token }
    subject { UserMailer.reset_password(user.id, url).deliver_now }

    it { expect { subject }.to change { ActionMailer::Base.deliveries.count } }

    it 'email should contain proper password and url' do
      email = subject
      expect(email.body.to_s).to include(url)
    end
  end
end
