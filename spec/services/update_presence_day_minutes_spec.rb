require 'rails_helper'

RSpec.describe UpdatePresenceDayMinutes, type: :service do
  let(:presence_policy) { create(:presence_policy) }
  let(:presence_day) { create(:presence_day, presence_policy: presence_policy) }
  let!(:time_entry) do
    create(:time_entry, start_time: '12:00', end_time: '00:00', presence_day: presence_day)
  end
  subject { UpdatePresenceDayMinutes.new(params).call }
  let(:params) { [presence_day] }

  context 'when time entry does not have related entry' do
    context 'when valid params' do
      it { expect { subject }.to change { presence_day.reload.minutes }.from(nil).to(720) }
    end

    context 'when invalid params' do
      before { allow(presence_day).to receive(:valid?) { false } }

      it { expect { subject }.to_not change { presence_day.reload.minutes } }
    end
  end

  context 'when time entry does not have start time' do
    before { time_entry[:start_time] = 'test' }

    it { expect { subject }.to_not raise_exception }
  end

  context 'when time entry does not have end time' do
    before { time_entry[:end_time] = 'test' }

    it { expect { subject }.to_not raise_exception }
  end

  context 'when time entry has related entry' do
    let(:params) { [presence_day, related_day] }
    let(:related_day) do
      create(:presence_day, presence_policy: presence_policy, order: presence_day.order + 1)
    end
    let!(:related_entry) do
      create(:time_entry, start_time: '00:00', end_time: '10:00', presence_day: related_day)
    end

    it { expect { subject }.to change { presence_day.reload.minutes }.from(nil).to(720) }
    it { expect { subject }.to change { related_day.reload.minutes }.from(nil).to(600) }
  end
end
