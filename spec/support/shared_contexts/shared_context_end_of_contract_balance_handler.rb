RSpec.shared_context "end of contract balance handler context" do
  # NOTE: to use this context you need to pass the mocks in the event's initializer like this:
  # let(:subject) do
  #   described_class
  #     .new(
  #       find_and_destroy_eoc_balance: find_and_destroy_eoc_balance_mock,
  #       create_eoc_balance: create_eoc_balance_mock,
  #       find_first_eoc_event_after: find_first_eoc_event_after_mock,
  #     )
  #     .call(event, params)
  # end

  let(:find_and_destroy_eoc_balance_mock) do
    instance_double(Balances::EndOfContract::FindAndDestroy, call: true)
  end

  let(:create_eoc_balance_mock) do
    instance_double(Balances::EndOfContract::Create, call: true)
  end

  let(:find_first_eoc_event_after_mock) do
    instance_double(Events::ContractEnd::FindFirstAfter, call: eoc_event)
  end

  let(:eoc_event) { nil }
end
