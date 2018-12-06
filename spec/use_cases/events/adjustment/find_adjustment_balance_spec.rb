require "rails_helper"

RSpec.describe Events::Adjustment::FindAdjustmentBalance do
  subject do
    described_class.new(employee_balance_model: employee_balance_model_mock).call(event)
  end

  let(:employee_balance_model_mock) { class_double(Employee::Balance, find_by!: balance) }
  let(:balance) { build(:employee_balance) }
  let(:event) { build(:employee_event) }
  let(:account) { build(:account) }

  it "finds the balance" do
    expect(subject).to eq(balance)
    expect(employee_balance_model_mock)
      .to have_received(:find_by!)
      .with(
        time_off_category_id: event.account.vacation_category.id,
        employee_id: event.employee_id,
        effective_at: event.effective_at + Employee::Balance::MANUAL_ADJUSTMENT_OFFSET
      )
  end
end
