RSpec.shared_examples "end of contract balance find and destroy" do
  let(:find_and_destroy_end_of_contract_balance_mock) do
    instance_double(Balances::EndOfContract::FindAndDestroy, call: true)
  end

  before do
    allow(Balances::EndOfContract::FindAndDestroy).to receive(:new).and_return(
      find_and_destroy_end_of_contract_balance_mock
    )
  end

  it "finds and destroys end_of_contract balance for vacation time off category" do
    subject
    expect(find_and_destroy_end_of_contract_balance_mock).to have_received(:call).with(
      employee: employee,
      eoc_date: old_contract_end_date + 1,
    )
  end
end
