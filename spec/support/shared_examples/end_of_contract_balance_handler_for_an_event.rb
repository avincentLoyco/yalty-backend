RSpec.shared_examples "end of contract balance handler for an event" do
  context "when there is end of contract event" do
    let(:eoc_event) { build(:employee_event) }

    it "handles end of contract balance" do
      subject
      expect(find_first_eoc_event_after_mock)
        .to have_received(:call)
        .with(effective_at: effective_at, employee: event.employee)

      expect(find_and_destroy_eoc_balance_mock)
        .to have_received(:call)
        .with(employee: event.employee, eoc_date: eoc_event.effective_at)

      expect(create_eoc_balance_mock)
        .to have_received(:call)
        .with(
          employee: event.employee,
          contract_end_date: eoc_event.effective_at,
          eoc_event_id: eoc_event.id
        )
    end

  end

  context "when there is no end of contract event" do
    let(:eoc_event) { nil }

    it "does not handle end of contract balance" do
      subject
      expect(find_first_eoc_event_after_mock)
        .to have_received(:call)
        .twice
        .with(effective_at: effective_at, employee: event.employee)

      expect(find_and_destroy_eoc_balance_mock).not_to have_received(:call)
      expect(create_eoc_balance_mock).not_to have_received(:call)
    end
  end
end
