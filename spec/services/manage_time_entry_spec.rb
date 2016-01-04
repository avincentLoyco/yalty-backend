require 'rails_helper'

RSpec.describe ManageTimeEntry, type: :service do
  subject { ManageTimeEntry.new(params, presence_day).call }
  let(:params) {{ start_time: '12:00', end_time: end_time}}
  let(:account) { create(:account) }
  let(:presence_policy) { create(:presence_policy, account: account) }
  let!(:presence_day) { create(:presence_day, order: 1, presence_policy: presence_policy) }
  let(:end_time) { '23:00:00' }

  context 'with valid params' do
    context 'time entry does not exist' do
      context 'end time in current presence day' do
        it { expect { subject }.to change { TimeEntry.count }.by(1) }
        it { expect { subject }.to_not change { PresenceDay.count } }

        it { expect(subject.presence_day_id).to eq presence_day.id }
      end

      context 'end time in next presence day' do
        let(:end_time) { '10:00' }

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

    context 'time entry exist' do
      let!(:time_entry) { create(:time_entry, presence_day: presence_day) }

      context 'does not have related entry' do
        context 'and new entry in new day' do
          let(:end_time) { '2:00' }
          before { params[:id] = time_entry.id }

          it { expect { subject }.to change { time_entry.reload.end_time }.to('00:00:00') }
          it { expect { subject }.to change { TimeEntry.count }.by(1) }
          it { expect { subject }.to change { PresenceDay.count }.by(1) }
        end

        context 'and new entry in one day' do
          before { params[:id] = time_entry.id }

          it { expect { subject }.to change { time_entry.reload.end_time }.to(end_time) }
          it { expect { subject }.to_not change { TimeEntry.count } }
          it { expect { subject }.to_not change { PresenceDay.count } }
        end
      end

      context 'has related entry' do
        let!(:time_entry) { create(:time_entry, presence_day: presence_day, end_time: '00:00:00') }
        let(:related_day) { create(:presence_day, presence_policy: presence_policy, order: 2) }
        let!(:related_entry) { create(:time_entry, presence_day: related_day, start_time: '00:00') }
        before { params[:id] = time_entry.id }

        context 'and new entry in new day' do
          let(:end_time) { '02:00:00' }

          it { expect { subject }.to change { related_entry.reload.end_time }.to(end_time) }
          it { expect { subject }.to_not change { TimeEntry.count } }
          it { expect { subject }.to_not change { PresenceDay.count } }
        end

        context 'and new entry in one day' do
          let(:end_time) { '14:00' }

          it { expect { subject }.to change { time_entry.reload.end_time } }
          it { expect { subject }.to change { TimeEntry.count }.by(-1) }
        end
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
