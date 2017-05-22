require "rails_helper"

RSpec.describe YaltyAccessMailer, type: :mailer do
  context '#access_enable' do
    let(:account) { create(:account, yalty_access: true, default_locale: 'en') }
    let(:owners) { account.users.where(role: 'account_owner').all }

    subject { YaltyAccessMailer.access_enable(account).deliver_now }

    it { expect { subject }.to change { ActionMailer::Base.deliveries.count } }
    it { expect(subject.body.to_s).to include(account.company_name) }
    it { expect(subject.body.to_s).to include(account.id) }
    it { expect(subject.body.to_s).to include("#{account.subdomain}.#{ENV['YALTY_APP_DOMAIN']}") }
    it { expect(subject.body.to_s).to include('English') }
    it 'should include all owner email' do
      create_list(:account_user, 2, account: account, role: 'account_owner')

      expect(owners.count).to be_eql(2)
      owners.each do |user|
        expect(subject.body.to_s).to include(user.email)
      end
    end
  end
end
