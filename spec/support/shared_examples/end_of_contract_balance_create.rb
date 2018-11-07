RSpec.shared_examples "end of contract balance create" do
  let(:create_end_of_contract_balance_mock) do
    instance_double(Balances::EndOfContract::Create, call: true)
  end

  let(:eoc_balance_effective_at) do
    employee_vacation_time_off_policy
      .employee_balances
      .first
      .effective_at.to_date.to_time(:utc) + Employee::Balance::END_OF_CONTRACT_OFFSET
  end

  before do
    allow(Balances::EndOfContract::Create).to receive(:new).and_return(
      create_end_of_contract_balance_mock
    )
  end

  it "creates end_of_contract balance for vacation time off category" do
    subject
    expect(create_end_of_contract_balance_mock).to have_received(:call).with(
      employee: employee,
      vacation_toc_id: vacation_toc.id,
      effective_at: eoc_balance_effective_at,
      event_id: event.id,
    )
  end
end
