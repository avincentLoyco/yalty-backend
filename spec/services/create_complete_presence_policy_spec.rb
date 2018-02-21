require "rails_helper"

RSpec.describe CreateCompletePresencePolicy, type: :service do

  describe "#call" do
    let!(:presence_policy) { create(:presence_policy) }
    let(:first_time_entry) do
      [
        {
          start_time: "16:00:00" ,
          end_time: "16:20:00"
        } ,
        {
          start_time: "18:20:00",
          end_time: "18:20:00"
        } ,
      ]
    end
    let(:second_time_entry) do
      [
        {
          start_time: "12:00:00",
          end_time: "13:00:00"
        },
        {
          start_time: "15:00:00",
          end_time: "16:00:00"
        },
      ]
    end
    let(:presence_day_params) do
      [
        {
          time_entries: first_time_entry,
          minutes: 40,
          order: 1
        },
        {
          time_entries: second_time_entry,
          minutes: 120,
          order: 2
        }
      ]
    end
    let(:active_record_params) {
      ActionController::Parameters.new(dummy_key: presence_day_params).delete(:dummy_key)
    }

    subject { described_class.new(presence_policy, active_record_params).call() }
    context "with time_entries" do

      it { expect { subject }.to change { presence_policy.reload.presence_days.count }.by(2) }
      it { expect { subject }.to change { TimeEntry.count }.by(4) }
    end

    context "without time_entries" do
      let(:first_time_entry) { [] }
      let(:second_time_entry) { [] }

      it { expect { subject }.to change { presence_policy.reload.presence_days.count }.by(2) }
      it { expect { subject }.not_to change { TimeEntry.count } }
    end

    context "with empty params" do
      let(:active_record_params) {
        ActionController::Parameters.new(dummy_key: []).delete(:dummy_key)
      }

      it { expect { subject }.not_to change { presence_policy.reload.presence_days.count } }
      it { expect { subject }.not_to change { TimeEntry.count } }
    end
  end
end
