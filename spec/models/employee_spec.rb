require "rails_helper"

RSpec.describe Employee, type: :model do
  include_context "shared_context_account_helper"
  include_context "shared_context_timecop_helper"

  subject { build(:employee) }

  it { is_expected.to have_db_column(:account_id).of_type(:uuid) }
  it { is_expected.to belong_to(:account).inverse_of(:employees) }
  it { is_expected.to respond_to(:account) }
  # TODO: New validations
  # it { is_expected.to validate_presence_of(:account) }

  it { is_expected.to have_many(:employee_attribute_versions).inverse_of(:employee) }
  it { is_expected.to have_many(:time_offs) }
  it { is_expected.to have_many(:employee_working_places) }
  it { is_expected.to have_many(:employee_balances) }

  it { is_expected.to have_many(:employee_attributes).inverse_of(:employee) }

  it { is_expected.to have_many(:events).inverse_of(:employee) }
  it { is_expected.to have_many(:presence_policies) }
  it { is_expected.to have_many(:registered_working_times) }

  it { is_expected.to belong_to(:user).inverse_of(:employee) }
  it do
    subject.user = create(:account_user, account: subject.account)
    is_expected.to validate_uniqueness_of(:user).scoped_to(:account_id).allow_nil
  end

  it do
    user = create(:account_user)
    employee = user.employee
    expect(employee).to validate_presence_of(:user)
  end

  it do
    employee = create(:employee, user: nil)
    expect(employee).to_not validate_presence_of(:user)
  end

  context "scopes" do
    let(:account) { create(:account) }
    let(:employee) { create(:employee, account: account) }
    let!(:account_user) { create(:account_user, account: account, employee: employee) }
    let!(:employees_same_account) { create_list(:employee, 3, account: account) }
    let!(:employees_different_account) { create_list(:employee, 3) }
    let(:all_employees) { [employee] + employees_same_account + employees_different_account }

    context ".active_by_account" do
      subject(:active_by_account_scope) { described_class.active_by_account(account.id) }

      it "returns only employees with users / active employees" do
        expect(active_by_account_scope.count).to eq(4)
        expect(active_by_account_scope).to include(employee)
      end
    end

    context "active and inactive" do
      context "there are hired events in the future" do
        it { expect(described_class.active_at_date.count).to eq(7) }
        it { expect(described_class.inactive_at_date.count).to eq(0) }

        context "there is contract_end after hired" do
          let!(:contract_end) do
            create(:employee_event, employee: employee, event_type: "contract_end",
              effective_at: 1.year.from_now)
          end

          it { expect(described_class.active_at_date.count).to eq(7) }
          it { expect(described_class.inactive_at_date.count).to eq(0) }
        end
      end

      context "there no hired events in the future" do
        let!(:contract_end) do
          create(:employee_event, employee: employee, event_type: "contract_end",
            effective_at: 1.year.from_now)
        end

        it { expect(described_class.active_at_date(2.years.from_now).count).to eq(6) }
        it { expect(described_class.inactive_at_date(2.years.from_now).count).to eq(1) }
        it { expect(described_class.inactive_at_date(2.years.from_now)).to include(employee) }

        context "there is contract_end in the future" do
          it { expect(described_class.active_at_date.count).to eq(7) }
          it { expect(described_class.inactive_at_date.count).to eq(0) }
        end
      end

      context "employee is rehired" do
        let!(:contract_end) do
          create(:employee_event, employee: employee, event_type: "contract_end",
            effective_at: 1.month.from_now)
        end

        let!(:rehired) do
          create(:employee_event, employee: employee, event_type: "hired",
            effective_at: 5.months.from_now)
        end

        it { expect(described_class.active_at_date(2.years.from_now).count).to eq(7) }
        it { expect(described_class.inactive_at_date(2.years.from_now).count).to eq(0) }
        it { expect(described_class.inactive_at_date(2.years.from_now)).to_not include(employee) }
      end

      context "should be active on the day of contract_end" do
        let!(:contract_end) do
          create(:employee_event, employee: employee, event_type: "contract_end",
            effective_at: Time.zone.now)
        end

        it { expect(described_class.active_at_date.count).to eq(7) }
        it { expect(described_class.inactive_at_date.count).to eq(0) }
      end

      context "should be active on the day of hired event" do
        let(:hired_date) { employee.events.find_by(event_type: "hired").effective_at }

        it { expect(described_class.active_at_date(hired_date).count).to eq(7) }
        it { expect(described_class.inactive_at_date(hired_date).count).to eq(0) }
      end
    end

    context "active_employee_ratio_per_account" do
      subject(:active_employee_ratio) do
        described_class.active_employee_ratio_per_account(account.id)
      end

      it "returns proper ratio" do
        expect(active_employee_ratio).to eq(25.00)
      end
    end
  end

  context "callbacks" do
    context ".trigger_intercom_update" do
      let!(:account) { create(:account) }
      let(:employee) { build(:employee, account: account) }

      # TODO: New validations
      # it 'should trigger create_or_update_on_intercom on account' do
      #   expect(account).to receive(:create_or_update_on_intercom).with(true)
      #   employee.save!
      # end

      context "with user" do
        let!(:user) { build(:account_user, account: account) }
        let!(:employee) { create(:employee, account: account) }

        it "should trigger intercom update on user" do
          expect(user).to receive(:create_or_update_on_intercom)
          employee.user = user
          employee.save!
        end
      end

      context "without user" do
        it "should not trigger intercom update on user" do
          expect_any_instance_of(Account::User)
            .not_to receive(:create_or_update_on_intercom)
          employee.save!
        end
      end
    end
  end

  context "methods" do
    let(:employee) { create(:employee) }

    context "can_be_hired?" do
      let(:hired_event) { employee.events.find_by(event_type: "hired") }

      context "when there is no contract end" do
        it { expect(employee.can_be_hired?).to eq(false) }
      end

      context "when checked after contract_end" do
        let!(:contract_end) do
          create(:employee_event, employee: employee, effective_at: 1.month.ago,
            event_type: "contract_end")
        end

        it { expect(employee.can_be_hired?).to eq(true) }
      end
    end

    context "for generic_files" do
      let(:generic_files) { create_list(:generic_file, 2, :with_jpg) }
      let!(:employee_attributes) do
        generic_files.each do |file|
          create(:employee_attribute, employee: employee, attribute_type: "File", data: {
            id: file.id,
            size: file.file_file_size,
            file_type: file.file_content_type,
            file_sha: "123",
          })
        end
      end
      let(:total_amount_of_data) { generic_files.sum(&:file_file_size) / (1024.0 * 1024.0) }

      it { expect(employee.total_amount_of_data).to eq(total_amount_of_data.round(2)) }
      it { expect(employee.number_of_files).to eq(2) }
    end

    context "civil status" do
      context "when employee has civil status changes" do
        include_context "shared_context_timecop_helper"
        before { employee.reload.events }

        let!(:wedding_event) do
          create(:employee_event,
            effective_at: 1.year.ago, employee: employee, event_type: "marriage")
        end
        let!(:divorce_event) do
          create(:employee_event,
            effective_at: Time.zone.today, employee: employee, event_type: "divorce")
        end

        context "and date param is not given" do
          it { expect(employee.civil_status_for).to eq "divorced" }
          it { expect(employee.civil_status_date_for).to eq divorce_event.effective_at }
        end

        context "and date param is given" do
          it { expect(employee.civil_status_for(5.months.ago)).to eq "married" }
          it do
            expect(employee.civil_status_date_for(5.months.ago)).to eq wedding_event.effective_at
          end
        end
      end

      context "when employee does not have civil status changes" do
        it { expect(employee.civil_status_for).to eq "single" }
        it { expect(employee.civil_status_date_for).to eq nil }
      end
    end

    context "#contract periods" do
      let(:employee) { create(:employee) }

      subject { employee.contract_periods }

      it { expect(subject).to eq([employee.hired_date..Date::Infinity.new]) }

      context "when employee has hired and contract end in the same day" do
        before do
          create(:employee_event,
            event_type: "contract_end", employee: employee, effective_at: employee.hired_date)
        end

        it { expect(subject).to eq([employee.hired_date..employee.hired_date]) }

        context "and there is rehired event one day after contract end and first hire" do
          before do
            create(:employee_event,
              event_type: "hired", employee: employee, effective_at: employee.hired_date + 1.day)
          end

          let(:hired_date) { employee.events.order(:effective_at).first.effective_at }

          it do
            expect(subject).to eq(
              [hired_date..hired_date, (hired_date + 1.day)..Date::Infinity.new]
            )
          end
        end
      end
    end

    context "#fullname" do
      let(:hired_event) { employee.events.find_by(event_type: "hired") }
      let(:firstname) { "John" }
      let(:lastname) { "Doe" }

      before do
        Account::DEFAULT_ATTRIBUTE_DEFINITIONS.each do |attr|
          next unless %w(firstname lastname).include?(attr[:name])

          create(:employee_attribute_definition,
            account: employee.account,
            name: attr[:name],
            attribute_type: attr[:type],
            system: true,
            multiple: false,
            validation: attr[:validation]
          )

          value = build(:employee_attribute_version,
            event: hired_event,
            employee: employee,
            attribute_name: attr[:name]
          )
          value.value = send(attr[:name].to_sym)
          value.save!
        end
      end

      it { expect(employee.fullname).to eq "John Doe" }
    end

    context "#hired_date" do
      include_context "shared_context_timecop_helper"
      let(:employee) { create(:employee, hired_at: hired_at, contract_end_at: contract_end_at) }

      let(:contract_end_at) { nil }
      let(:rehired_at) { nil }
      let(:contract_end_after_rehired_at) { nil }

      before do
        if rehired_at
          employee.events << build(:employee_event,
            event_type: "hired",
            employee: employee,
            effective_at: rehired_at
          )
          if contract_end_after_rehired_at
            employee.events << build(:employee_event,
              event_type: "contract_end",
              employee: employee,
              effective_at: contract_end_after_rehired_at
            )
          end
        end

        employee.events.reload
      end

      context "when hired in past" do
        let(:hired_at) { 1.month.ago.to_date }

        it { expect(employee.hired_date).to eql(hired_at) }
        it { expect(employee.contract_end_date).to be_nil }
      end

      context "when hired in future" do
        let(:hired_at) { 1.month.from_now.to_date }

        it { expect(employee.hired_date).to eql(hired_at) }
        it { expect(employee.contract_end_date).to be_nil }
      end

      context "when hired in past and fired in past" do
        let(:hired_at) { 2.month.ago.to_date }
        let(:contract_end_at) { 1.month.ago.to_date }

        it { expect(employee.hired_date).to eql(hired_at) }
        it { expect(employee.contract_end_date).to eql(contract_end_at) }
      end

      context "when hired in past and fired in future" do
        let(:hired_at) { 1.month.ago.to_date }
        let(:contract_end_at) { 1.month.from_now.to_date }

        it { expect(employee.hired_date).to eql(hired_at) }
        it { expect(employee.contract_end_date).to eql(contract_end_at) }
      end

      context "when fired in past then rehired in past" do
        let(:hired_at) { 3.month.ago.to_date }
        let(:contract_end_at) { 2.month.ago.to_date }

        let(:rehired_at) { 1.month.ago.to_date }

        it { expect(employee.hired_date).to eql(rehired_at) }
        it { expect(employee.contract_end_date).to be_nil }
      end

      context "when fired in past then rehired in future" do
        let(:hired_at) { 3.month.ago.to_date }
        let(:contract_end_at) { 2.month.ago.to_date }

        let(:rehired_at) { 1.month.from_now.to_date }

        it { expect(employee.hired_date).to eql(rehired_at) }
        it { expect(employee.contract_end_date).to be_nil }
      end

      context "when fired in future then rehired" do
        let(:hired_at) { 1.month.ago.to_date }
        let(:contract_end_at) { 1.month.from_now.to_date }

        let(:rehired_at) { 2.month.from_now.to_date }

        it { expect(employee.hired_date).to eql(hired_at) }
        it { expect(employee.contract_end_date).to eql(contract_end_at) }
      end

      context "when fired in past then rehired in past and fired again in future" do
        let(:hired_at) { 3.month.ago.to_date }
        let(:contract_end_at) { 2.month.ago.to_date }

        let(:rehired_at) { 1.month.ago.to_date }
        let(:contract_end_after_rehired_at) { 1.month.from_now.to_date }

        it { expect(employee.hired_date).to eql(rehired_at) }
        it { expect(employee.contract_end_date).to eql(contract_end_after_rehired_at) }
      end

      context "when fired in past then rehired in future and fired again" do
        let(:hired_at) { 3.month.ago.to_date }
        let(:contract_end_at) { 2.month.ago.to_date }

        let(:rehired_at) { 1.month.from_now.to_date }
        let(:contract_end_after_rehired_at) { 2.month.from_now.to_date }

        it { expect(employee.hired_date).to eql(rehired_at) }
        it { expect(employee.contract_end_date).to eql(contract_end_after_rehired_at) }
      end
    end
    context "#hired_at" do
      let(:employee) { create(:employee, hired_at: hired_at, contract_end_at: contract_end_at) }

      let(:contract_end_at) { nil }
      let(:rehired_at) { nil }
      let(:contract_end_after_rehired_at) { nil }

      before do
        if rehired_at
          employee.events << build(:employee_event,
            event_type: "hired",
            employee: employee,
            effective_at: rehired_at
          )
          if contract_end_after_rehired_at
            employee.events << build(:employee_event,
              event_type: "contract_end",
              employee: employee,
              effective_at: contract_end_after_rehired_at
            )
          end
        end

        employee.events.reload
      end

      context "when hired in past" do
        let(:hired_at) { 1.month.ago.to_date }

        it { expect(employee.hired_at?(Date.today)).to be(true) }
      end

      context "when hired in future" do
        let(:hired_at) { 1.month.from_now.to_date }

        it { expect(employee.hired_at?(Date.today)).to be(false) }
      end

      context "when hired in past and fired in past" do
        let(:hired_at) { 2.month.ago.to_date }
        let(:contract_end_at) { 1.month.ago.to_date }

        it { expect(employee.hired_at?(Date.today)).to be(false) }
      end

      context "when hired in past and fired in future" do
        let(:hired_at) { 1.month.ago.to_date }
        let(:contract_end_at) { 1.month.from_now.to_date }

        it { expect(employee.hired_at?(Date.today)).to be(true) }
      end

      context "when fired in past then rehired in past" do
        let(:hired_at) { 3.month.ago.to_date }
        let(:contract_end_at) { 2.month.ago.to_date }

        let(:rehired_at) { 1.month.ago.to_date }

        it { expect(employee.hired_at?(Date.today)).to be(true) }
      end

      context "when fired in past then rehired in future" do
        let(:hired_at) { 3.month.ago.to_date }
        let(:contract_end_at) { 2.month.ago.to_date }

        let(:rehired_at) { 1.month.from_now.to_date }

        it { expect(employee.hired_at?(Date.today)).to be(false) }
      end

      context "when fired in past then rehired in past and fired again in future" do
        let(:hired_at) { 3.month.ago.to_date }
        let(:contract_end_at) { 2.month.ago.to_date }

        let(:rehired_at) { 1.month.ago.to_date }
        let(:contract_end_after_rehired_at) { 1.month.from_now.to_date }

        it { expect(employee.hired_at?(Date.today)).to be(true) }
      end
    end
  end
end
