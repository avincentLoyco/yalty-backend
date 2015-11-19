require "rails_helper"

RSpec.describe UserMailer, type: :mailer do
  context '#credentials' do
    let(:user) { create(:account_user) }
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
end
