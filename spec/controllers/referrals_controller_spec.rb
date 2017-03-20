require 'rails_helper'

RSpec.describe ReferralsController, type: :controller do
  describe 'POST #create' do
    let(:email) { 'test@example.com' }
    let(:params) { { email: email } }
    let(:intercom_user) { double(id: 123, email: email) }

    before do
      allow_any_instance_of(Intercom::Client)
        .to receive_message_chain(:contacts, :find_all)
        .and_return([intercom_user])

      allow_any_instance_of(Intercom::Client)
        .to receive_message_chain(:tags, :tag)
        .and_return(nil)
    end

    subject { post :create, params }

    context 'with valid params' do
      context 'new Referrer' do
        context 'valid response' do
          before { subject }

          it { is_expected.to have_http_status(200) }
          it { expect(JSON.parse(response.body).keys).to match_array(%w(email referral_token)) }
          it { expect(JSON.parse(response.body)['email']).to eq(email) }
        end

        it { expect { subject }.to change(Referrer, :count).by(1) }
      end

      context 'Referrer with provided email exists' do
        let!(:referrer) { create(:referrer, email: email) }

        context 'valid response' do
          before { subject }
          it { is_expected.to have_http_status(200) }
          it do
            expect(JSON.parse(response.body))
              .to include({ 'email' => email, 'referral_token' => referrer.token })
          end
        end

        it { expect { subject }.to_not change(Referrer, :count) }
      end
    end

    context 'with invalid params' do
      shared_examples 'invalid params' do
        it { is_expected.to have_http_status(422) }
      end

      context 'when email not send' do
        let(:params) { {} }
        it_behaves_like 'invalid params'
      end

      context 'when email is empty' do
        let(:params) { { email: '' } }
        it_behaves_like 'invalid params'
      end

      context 'when email is invalid' do
        let(:params) { { email: 123 } }
        it_behaves_like 'invalid params'
      end
    end
  end

  describe 'GET #referrers.csv' do
    before { Timecop.freeze(Date.new(2016, 1, 1)) }
    after { Timecop.return }

    let!(:referrers) { create_list(:referrer, 3) }

    let!(:accounts) do
      [2.years.ago, 1.year.ago, Time.zone.now].each do |date|
        create(:account, referred_by: referrers.first.token, created_at: date)
        create(:account, referred_by: referrers.second.token, created_at: date)
      end
    end

    let(:array_from_csv) { CSV.parse(response.body) }
    subject { get :referrers_csv, params, @env }

    context 'without params' do
      let(:params) { { format: :csv } }

      before do
        referral_http_login
        subject
      end

      it { is_expected.to have_http_status(200) }

      it 'does not include referrers without accounts' do
        expect(Referrer.count).to eq(3)
        expect(array_from_csv.size).to eq(4)
      end

      it 'counts referred accounts from all time' do
        expect(array_from_csv[2][2]).to eq('3')
        expect(array_from_csv[3][2]).to eq('3')
      end
    end

    context 'with params' do
      before { referral_http_login }

      context 'with from param' do
        let(:from_param) { '2015-01-01' }
        let(:params) { { format: :csv, from: from_param } }
        before { subject }

        it 'does not count accounts created before from param' do
          expect(array_from_csv[0][1]).to eq(Time.zone.parse(from_param).to_s)
          expect(array_from_csv[2][2]).to eq('2')
          expect(array_from_csv[3][2]).to eq('2')
        end
      end

      context 'with to param' do
        let(:to_param) { '2015-12-31' }
        let(:params) { { format: :csv, to: to_param } }
        before { subject }

        it 'does not count accounts created after to param' do
          expect(array_from_csv[0][2]).to eq(Time.zone.parse(to_param).end_of_day.to_s)
          expect(array_from_csv[2][2]).to eq('2')
          expect(array_from_csv[3][2]).to eq('2')
        end
      end

      context 'with both params' do
        let(:from_param) { '2015-01-01' }
        let(:to_param) { '2015-12-31' }
        let(:params) { { format: :csv, from: from_param, to: to_param } }
        before { subject }

        it 'does not count accounts out of boundries' do
          expect(array_from_csv[0][1]).to eq(Time.zone.parse(from_param).to_s)
          expect(array_from_csv[0][3]).to eq(Time.zone.parse(to_param).end_of_day.to_s)
          expect(array_from_csv[2][2]).to eq('1')
          expect(array_from_csv[3][2]).to eq('1')
        end
      end
    end
  end
end
