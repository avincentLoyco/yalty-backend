require 'rails_helper'

RSpec.describe ManageTimeEntry, type: :service do
  subject { ManageTimeEntry.new(params, presence_day).call }
  let(:params) {{ start_time: '12:00', end_time: '23:00' }}
  let(:account) { create(:account) }
  let(:presence_policy) { create(:presence_policy, account: account) }
  let!(:presence_day) { create(:presence_day, order: 1, presence_policy: presence_policy) }

  context 'with valid params' do
    context 'end time in current presence day' do
      it { expect { subject }.to change { TimeEntry.count }.by(1) }
      it { expect { subject }.to_not change { PresenceDay.count } }

      it { expect(subject.presence_day_id).to eq presence_day.id }
    end

    context 'end time in next presence day' do
      before { params[:end_time] =  '2:00' }

      context 'presence day exist' do
        let!(:next_presence_day) do
          create(:presence_day, order: 2, presence_policy: presence_policy)
        end

        it { expect { subject }.to change { TimeEntry.count }.by(2) }
        it { expect { subject }.to_not change { PresenceDay.count } }
        it { expect(subject.length).to eq 2 }
      end

      context 'presence day do not exist' do
        it { expect { subject }.to change { TimeEntry.count }.by(2) }
        it { expect { subject }.to change { PresenceDay.count }.by(1) }

        it { expect(subject.length).to eq 2 }
      end
    end
  end

  context 'with invalid params' do
    context 'time entry data does not pass validation' do
      context 'invalid time format' do
        before { params[:end_time] = 'test' }

        it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
      end

      context 'params not present' do
        before { params[:end_time] = '' }

        it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
      end
    end

    context 'presence day data does not pass validation' do
      before { params[:end_time] =  '2:00' }
      before { allow_any_instance_of(PresenceDay).to receive(:valid?) { false } }

      it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
    end
  end
end
