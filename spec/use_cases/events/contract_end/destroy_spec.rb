require "rails_helper"

RSpec.describe Events::ContractEnd::Destroy do
  describe "#call" do
    subject do
      described_class
        .new(
          find_and_destroy_eoc_balance: find_and_destroy_eoc_balance_mock,
          delete_event_service: delete_event_service_class_mock,
        )
        .call(event)
    end

    let(:event) { build(:employee_event) }
    let(:etop) { build(:employee_time_off_policy, employee_event: event) }

    let(:find_and_destroy_eoc_balance_mock) do
      instance_double(Balances::EndOfContract::FindAndDestroy, call: true)
    end

    let(:delete_event_service_instance_mock) { instance_double(CreateEvent, call: event) }
    let(:delete_event_service_class_mock) do
      class_double(DeleteEvent, new: delete_event_service_instance_mock)
    end

    before do
      etop
      allow(event).to receive(:save!)
      subject
    end

    it "unassigns employee time off policy from event" do
      expect(event.employee_time_off_policy).to eq(nil)
    end

    it "deletes the event" do
      expect(delete_event_service_class_mock).to have_received(:new).with(event)
      expect(delete_event_service_instance_mock).to have_received(:call)
    end

    it "destroys end_of_contract balance" do
      expect(find_and_destroy_eoc_balance_mock).to have_received(:call).with(
        employee: event.employee, eoc_date: event.effective_at
      )
    end
  end
end
