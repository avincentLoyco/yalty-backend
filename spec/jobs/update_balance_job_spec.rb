require 'rails_helper'

RSpec.describe UpdateBalanceJob do
  subject { UpdateBalanceJob.perform_now(first_balance.id, { amount: 100 }) }

  let!(:first_balance) { create(:employee_balance, beeing_processed: true) }
  let!(:second_balance) { first_balance.dup }
  let!(:third_balance) { first_balance.dup}

  before do
    second_balance.update!(effective_at: Time.now + 1.week)
    third_balance.update!(effective_at: Time.now + 1.month)
  end

  describe '#perform' do
    shared_examples 'Balance and Beeing Processed Status Change' do
      it { expect { subject }.to change { second_balance.reload.balance } }
      it { expect { subject }.to change { third_balance.reload.balance } }

      it { expect { subject }.to change { second_balance.reload.beeing_processed }.to false }
      it { expect { subject }.to change { third_balance.reload.beeing_processed }.to false }

      it { expect { subject }.to_not change { second_balance.reload.amount } }
      it { expect { subject }.to_not change { third_balance.reload.amount } }
    end

    context 'with amount params' do
      it { expect { subject }.to change { first_balance.reload.balance } }
      it { expect { subject }.to change { first_balance.reload.amount }.to(100) }
      it { expect { subject }.to change { first_balance.reload.beeing_processed }.to false }

      it_behaves_like 'Balance and Beeing Processed Status Change'
    end

    context 'without amount param' do
      subject { UpdateBalanceJob.perform_now(second_balance.id) }
      before { first_balance.destroy! }

      it_behaves_like 'Balance and Beeing Processed Status Change'
    end

    context 'with time off id' do
      before { first_balance.time_off = time_off }
      subject do
        UpdateBalanceJob.perform_now(first_balance.id, { amount: 100,  time_off_id: time_off.id })
      end
      let(:time_off) { create(:time_off, beeing_processed: true) }

      it { expect { subject }.to change { time_off.reload.beeing_processed }.to false }
    end
  end
end
