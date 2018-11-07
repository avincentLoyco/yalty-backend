require "rails_helper"

# CreateContractEnd
RSpec.describe ContractEnds::Create, :service do
  include_context "shared_context_account_helper"
  include_context "shared_context_timecop_helper"

  subject(:create_contract_end) do
    described_class.call(
      employee: employee, contract_end_date: contract_end_date, event_id: event.id
    )
  end

  let(:account)  { create(:account) }
  let(:employee) { create(:employee, account: account) }

  let(:contract_end_date) { Time.zone.parse("2016/03/01") }

  let(:event) do
    create(:employee_event,
      employee: employee,
      event_type: "contract_end",
      effective_at: contract_end_date,
      employee_time_off_policy: employee_vacation_time_off_policy
    )
  end

  let(:vacation_toc) { create(:time_off_category, account: account, name: "vacation") }
  let(:time_off_categories) do
    create_list(:time_off_category, 2, account: account) + [vacation_toc]
  end

  let(:time_off_policies) do
    time_off_categories.map do |category|
      create(:time_off_policy, :with_end_date, time_off_category: category)
    end
  end

  let(:vacation_top) do
    time_off_policies.detect { |top| top.time_off_category_id == vacation_toc.id }
  end

  let(:vacation_balances) do
    employee
      .employee_balances
      .where(time_off_category_id: vacation_toc.id)
      .order(:effective_at)
  end

  before do
    Account.current = account
    allow(DeleteTypeInPeriod).to receive(:call).and_return([])
    allow(EmployeePolicy::DeleteInPeriod).to receive(:call).and_return([])
    allow(TimeOffs::DeleteInPeriod).to receive(:call).and_return([])
    allow_any_instance_of(AssignResetJoinTable).to receive(:call) { [] }
    allow_any_instance_of(AssignResetEmployeeBalance).to receive(:call) { [] }
  end

  context "for time offs around contract end" do
    let(:start_time) { "2016/2/20" }
    let(:end_time)   { "2016/3/10" }

    let(:last_time_off)  { employee.time_offs.order(:start_time).last }
    let(:first_time_off) { employee.time_offs.order(:start_time).first }

    let(:employee_time_off_policies) do
      time_off_policies.map do |policy|
        create(
          :employee_time_off_policy, :with_employee_balance,
          time_off_policy: policy,
          employee: employee,
          effective_at: Date.new(2011, 1, 1)
        )
      end
    end

    let(:employee_vacation_time_off_policy) do
      employee_time_off_policies.detect { |etop| etop.time_off_policy_id == vacation_top.id }
    end

    before do
      employee_time_off_policies

      [["2011/1/1", "2011/1/10"], [start_time, end_time]].map do |dates|
        create(
          :time_off,
          employee: employee,
          time_off_category: time_off_categories.first,
          start_time: dates[0],
          end_time: dates[1]
        )
      end
      TimeOffs::Approve.call(last_time_off)
    end

    it_behaves_like "end of contract balance create"

    it "moves time off end time at contract end" do
      expect { create_contract_end }
        .to change { last_time_off.reload.end_time.to_date }.to(contract_end_date)
    end

    it "leaves time off before contract end unchanged" do
      expect { create_contract_end }.not_to change { first_time_off.reload.start_time }
      expect { create_contract_end }.not_to change { first_time_off.reload.end_time }
    end

    context "when time offs starts and end at contract end" do
      let(:start_time) { "2016-03-01T08:00:00" }
      let(:end_time)   { "2016-03-01T16:00:00" }

      it_behaves_like "end of contract balance create"

      it "does not change time off" do
        expect { create_contract_end }.not_to change { last_time_off.reload.start_time }
        expect { create_contract_end }.not_to change { last_time_off.reload.end_time }
      end
    end
  end

  context "balances after contract end deletion" do
    let(:employee_time_off_policy_balance) { employee_some_time_off_policy.employee_balances.first }
    let(:employee_some_time_off_policy) do
      create(
        :employee_time_off_policy, :with_employee_balance,
        time_off_policy: time_off_policies.first,
        employee: employee,
        effective_at: contract_end_date + 4.days
      )
    end

    let(:employee_vacation_time_off_policy) do
      create(
        :employee_time_off_policy, :with_employee_balance,
        time_off_policy: vacation_top,
        employee: employee,
        effective_at: contract_end_date - 20.days
      )
    end
    let(:employee_time_off_policies) do
      [employee_some_time_off_policy, employee_vacation_time_off_policy]
    end

    before { employee_time_off_policies }

    it_behaves_like "end of contract balance create"

    it "deletes proper balance" do
      create_contract_end
      expect(employee.employee_balances.reload).not_to include(employee_time_off_policy_balance)
    end
  end
end
