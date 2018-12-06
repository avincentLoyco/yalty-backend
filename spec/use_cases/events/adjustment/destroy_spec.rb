require "rails_helper"

RSpec.describe Events::Adjustment::Destroy do
  include_context "event destroy context"
  include_context "end of contract balance handler context"

  subject do
    described_class.new(
      delete_event_service: delete_event_service_class_mock,
      destroy_employee_balance_service: destroy_employee_balance_service_mock,
      find_adjustment_balance: find_adjustment_balance_mock,
      find_and_destroy_eoc_balance: find_and_destroy_eoc_balance_mock,
      create_eoc_balance: create_eoc_balance_mock,
      find_first_eoc_event_after: find_first_eoc_event_after_mock,
    ).call(event)
  end

  let(:destroy_employee_balance_service_mock) { class_double(DestroyEmployeeBalance, call: true) }
  let(:delete_event_service_instance_mock) { instance_double(DeleteEvent, call: event) }
  let(:delete_event_service_class_mock) do
    class_double(DeleteEvent, new: delete_event_service_instance_mock)
  end
  let(:find_adjustment_balance_mock) do
    instance_double(Events::Adjustment::FindAdjustmentBalance, call: adjustment_balance)
  end

  let(:adjustment_balance) { build(:employee_balance) }

  it_behaves_like "event destroy example"
  it_behaves_like "end of contract balance handler for an event"

  it "finds and destroys adjustment balance" do
    subject
    expect(find_adjustment_balance_mock).to have_received(:call).with(event)
    expect(destroy_employee_balance_service_mock).to have_received(:call).with(adjustment_balance)
  end
end
