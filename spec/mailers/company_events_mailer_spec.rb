require "rails_helper"

RSpec.describe CompanyEventsMailer, type: :mailer do
  before do
    ENV['YALTY_ACCESS_EMAIL'] = 'yalty@access.com'
  end

  let(:account)        { create(:account, company_name: 'Wayne', yalty_access: true) }

  let(:title)          { 'Batman is Bruce Wayne' }
  let!(:event)         { create(:company_event, account: account, title: title) }
  let!(:owners)        { create_list(:account_user, 2, account: account, role: 'account_owner') }
  let!(:administrator) { create(:account_user, account: account, role: 'account_administrator') }
  let!(:user)          { create(:account_user, account: account, role: 'user') }

  subject(:mail) do
    described_class.event_changed(account, event, administrator.id, action).deliver_now
  end

  context 'create action' do
    let(:action) { 'create' }
    let(:expected_subject) { "#{account.company_name}: A company event was changed" }
    let(:mail_body) do
      "A Company Event has been created for #{account.company_name} on"
    end

    it { expect(mail.subject).to eq(expected_subject) }
    it { expect(mail.to).to match_array(owners.map(&:email) + ['yalty@access.com']) }
    it { expect(mail.from).to eq([ENV['YALTY_APP_EMAIL']]) }
    it { expect(mail.body).to match_regex(mail_body) }

    context 'when there are no user recipients' do
      subject(:mail) do
        described_class.event_changed(account, event, owners.first.id, action).deliver_now
      end

      before do
        Account::User.where.not(id: owners.first.id).delete_all
        account.update!(yalty_access: false)
      end

      it { expect(mail).to eq nil }
    end
  end

  context 'update action' do
    let(:action) { 'update' }
    let(:mail_body) do
      "A Company Event has been updated for #{account.company_name} on"
    end

    it { expect(mail.body).to match_regex(mail_body) }
  end

  context 'destroy action' do
    let(:action) { 'destroy' }
    let(:mail_body) do
      "A Company Event has been destroyed for #{account.company_name} on"
    end

    it { expect(mail.body).to match_regex(mail_body) }
  end
end
