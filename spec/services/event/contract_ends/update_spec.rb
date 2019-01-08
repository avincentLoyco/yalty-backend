require "rails_helper"

RSpec.describe ContractEnds::Update, :service do
  include_context "shared_context_account_helper"
  include_context "shared_context_timecop_helper"

  subject(:update_contract_end) do
    described_class.call(
      employee: employee,
      new_contract_end_date: new_contract_end_date,
      old_contract_end_date: old_contract_end_date,
      eoc_event_id: event.id
    )
  end

  let(:contract_end_date)     { new_contract_end_date }
  let(:hired_date)            { Time.zone.parse("2016/01/01") }
  let(:new_contract_end_date) { Time.zone.parse("2016/03/01") }
  let(:old_contract_end_date) { Time.zone.parse("2016/03/20") }
  let(:event) do
    create(:employee_event,
      employee: employee,
      event_type: "contract_end",
      effective_at: old_contract_end_date,
      employee_time_off_policy: employee_vacation_time_off_policy
    )
  end

  let(:account_user) { create(:account_user) }
  let(:account)      { account_user.account }
  let(:employee)     { account_user.employee }

  let(:vacation_balance) do
    create(
      :employee_balance,
      employee: employee,
      time_off_category: vacation_toc,
      effective_at: new_contract_end_date - 60.days
    )
  end
  let(:vacation_toc) { create(:time_off_category, account: account, name: "vacation") }
  let(:time_off_categories) do
    create_list(:time_off_category, 2, account: account) + [vacation_toc]
  end

  let(:reset_time_off_policy) do
    create(:time_off_policy, :reset, time_off_category: time_off_categories.first)
  end

  let(:time_off_policies) do
    time_off_categories.map do |category|
      create(:time_off_policy, :with_end_date, time_off_category: category)
    end
  end

  let(:vacation_top) do
    time_off_policies.detect { |top| top.time_off_category_id == vacation_toc.id }
  end

  let(:employee_vacation_time_off_policy) do
    create(:employee_time_off_policy, :with_employee_balance,
      time_off_policy: vacation_top,
      employee: employee,
      effective_at: hired_date
    )
  end

  let(:presence_policy) { create(:presence_policy, :with_presence_day, account: account) }
  let!(:employee_presence_policy) do
    create(
      :employee_presence_policy,
      presence_policy: presence_policy,
      effective_at: hired_date,
      employee: employee,
    )
  end

  before do
    event
    vacation_balance
    Account.current = account
    allow(Account::User).to receive(:current) { account_user }

    allow(DeleteTypeInPeriod).to receive(:call).and_return([])
    allow(EmployeePolicy::DeleteInPeriod).to receive(:call).and_return([])
    allow(TimeOffs::DeleteInPeriod).to receive(:call).and_return([])
    allow_any_instance_of(AssignResetJoinTable).to receive(:call) { [] }
    allow_any_instance_of(AssignResetEmployeeBalance).to receive(:call) { [] }
    allow_any_instance_of(Balances::EndOfContract::FindAndDestroy).to receive(:call) { true }
    allow_any_instance_of(ManageEmployeeBalanceAdditions).to receive(:call) { [] }
  end

  context "when old reset balances" do
    before do
      create(:employee_time_off_policy, :with_reset_balance,
        time_off_policy: reset_time_off_policy,
        employee: employee,
        effective_at: old_contract_end_date + 1.day
      )
    end

    it_behaves_like "end of contract balance find and destroy"
    it_behaves_like "end of contract balance create"

    it "employee balances do not include reset" do
      update_contract_end
      expect(employee.employee_balances.reload.map(&:balance_type)).not_to include("reset")
    end
  end

  context "for time offs around contract end" do
    before do
      time_off_policies.map do |policy|
        create(:employee_time_off_policy, :with_employee_balance,
          time_off_policy: policy,
          employee: employee,
          effective_at: Date.new(2011, 1, 1)
        )
      end

      [["2011/1/1", "2011/1/10"], [start_time, end_time]].map do |dates|
        create(:time_off, employee: employee, time_off_category: time_off_categories.first,
               start_time: dates[0], end_time: dates[1]
        )
      end

      TimeOffs::Approve.call(last_time_off)
    end

    let(:start_time) { "2016/2/20" }
    let(:end_time)   { "2016/3/10" }

    let(:last_time_off)  { employee.time_offs.order(:start_time).last }
    let(:first_time_off) { employee.time_offs.order(:start_time).first }

    it_behaves_like "end of contract balance find and destroy"
    it_behaves_like "end of contract balance create"

    it "moves time off end time at contract end" do
      expect { update_contract_end }
        .to change { last_time_off.reload.end_time.to_date }.to(new_contract_end_date)
    end

    it "leaves time off before contract end unchanged" do
      expect { update_contract_end }.not_to change { first_time_off.reload.start_time }
      expect { update_contract_end }.not_to change { first_time_off.reload.end_time }
    end

    context "when time offs starts and end at contract end" do
      let(:start_time) { "2016-03-01T08:00:00" }
      let(:end_time)   { "2016-03-01T16:00:00" }

      it_behaves_like "end of contract balance find and destroy"
      it_behaves_like "end of contract balance create"

      it "does not change time off" do
        expect { update_contract_end }.not_to change { last_time_off.reload.start_time }
        expect { update_contract_end }.not_to change { last_time_off.reload.end_time }
      end
    end
  end

  context "balances after contract end deletion" do
    let!(:hired_time_off_policy) do
      create(:employee_time_off_policy, :with_employee_balance,
        time_off_policy: time_off_policies.first,
        employee: employee,
        effective_at: new_contract_end_date - 20.days)
    end
    let(:employee_time_off_policy_balance) { employee_time_off_policy.employee_balances.first }
    let!(:employee_time_off_policy) do
      create(:employee_time_off_policy, :with_employee_balance,
        time_off_policy: time_off_policies.first,
        employee: employee,
        effective_at: new_contract_end_date + 4.days)
    end

    it_behaves_like "end of contract balance find and destroy"
    it_behaves_like "end of contract balance create"

    it { expect { update_contract_end }.to change { employee.reload.employee_balances.count } }

    it "deletes proper balance" do
      update_contract_end
      expect(employee.employee_balances.reload).not_to include(employee_time_off_policy_balance)
    end
  end
end
