require 'rails_helper'

RSpec.describe UpdateAffectedEmployeeBalances, type: :service do
  include ActiveJob::TestHelper

  subject { UpdateAffectedEmployeeBalances.new(presence_policy, employees).call }
  let(:presence_policy) { nil }
  let(:employees) { [] }

  context 'when nothing send' do
    it { expect { subject }.to_not change { enqueued_jobs.size } }
    it { expect { subject }.to_not raise_error }
  end

  context 'when presence policy send but not employees' do
    let(:presence_policy) { create(:presence_policy, :with_presence_day) }

    context 'and there is no employees who are using policy' do
      it { expect { subject }.to_not change { enqueued_jobs.size } }
      it { expect { subject }.to_not raise_error }
    end

    context 'and there are employees who are using policy' do

      context 'and they do not have time offs' do
        before { create_list(:employee, 2, :with_presence_policy, presence_policy: presence_policy) }

        it { expect { subject }.to_not change { enqueued_jobs.size } }
        it { expect { subject }.to_not raise_error }
      end

      context 'and they have time offs' do
        before { create_list(:employee, 2,:with_presence_policy, :with_time_offs, presence_policy: presence_policy) }

        it { expect { subject }.to change { enqueued_jobs.size } }
      end
    end
  end

  context 'when employees send but not policy' do
    let(:policy) { create(:presence_policy, :with_presence_day) }
    context 'when employees do not have time offs' do
      let(:employees) { create_list(:employee, 2, :with_presence_policy, presence_policy: presence_policy) }

      it { expect { subject }.to_not change { enqueued_jobs.size } }
      it { expect { subject }.to_not raise_error }
    end

    context 'when employeess have time offs' do
      let(:employees) do
        create_list(:employee, 2, :with_presence_policy, :with_time_offs, presence_policy: policy)
      end

      it { expect { subject }.to change { enqueued_jobs.size } }
    end
  end
end
