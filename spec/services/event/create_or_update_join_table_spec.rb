require 'rails_helper'

RSpec.describe CreateOrUpdateJoinTable, type: :service do
  include_context 'shared_context_account_helper'
  include_context 'shared_context_timecop_helper'
  before { Account.current = create(:account) }

  describe '#call' do
    let(:employee) { create(:employee, account: Account.current) }
    let(:join_table_resource) { nil }
    let(:params_effective_at) { '1/4/2015' }
    let(:params) do
      {
        effective_at: params_effective_at,
        employee_id: employee.id
      }.merge(resource_params)
    end

    subject do
      described_class.new(join_table_class, resource_class, params, join_table_resource).call
    end

    # TODO: Rework shared examples

    shared_examples 'Join Table create' do
      it { expect { subject }.to_not raise_error }

      it { expect { subject }.to change { join_table_class.exists?(existing_join_table.id) } }

      it { expect(subject[:result].effective_at).to eq params[:effective_at].to_date }
      it { expect(subject[:status]).to eq 201 }
    end

    shared_examples 'Join Table create that doesnt allow same resource one after another' do
      it { expect { subject }.to_not raise_error }

      it { expect { subject }.to change { join_table_class.exists?(existing_join_table.id) } }
      it { expect { subject }.to change { join_table_class.exists?(same_resource_after.id) } }
    end

    shared_examples 'Join Table create that allows same resource one after another' do
      it { expect { subject }.to_not raise_error }

      it { expect { subject }.not_to change { join_table_class.count } }
      it { expect { subject }.to change { join_table_class.exists?(existing_join_table.id) } }
      it { expect { subject }.not_to change { join_table_class.exists?(same_resource_after.id) } }

      it { expect(subject[:status]).to eq 201 }
    end

    shared_examples 'Join Table create with different resource after and effective till in past' do
      it { expect { subject }.to_not raise_error }

      it { expect { subject }.to change { join_table_class.count }.by(1) }
      it do
        expect(subject[:result].effective_till.to_s)
          .to eq (existing_join_table.effective_at - 1.day).to_s
      end
    end

    shared_examples 'Join Table create with different resource after, after Time now' do
      it { expect { subject }.to_not raise_error }

      it { expect { subject }.to change { join_table_class.count }.by(1) }
      it do
        expect(subject[:result].effective_till.to_s)
          .to eq (existing_join_table.effective_at - 1.day).to_s
      end
    end

    shared_examples 'Join Table create with different resource before and contract_end' do
      it { expect { subject }.to_not raise_error }
      it { expect(subject[:result].effective_at).to eq(params[:effective_at].to_date) }
      it { expect(subject[:status]).to eq(201) }
      it 'removes reset join table' do
        expect { subject }
          .to change { join_table_class.exists?(existing_join_table.id) }
          .from(true)
          .to(false)
      end
    end

    shared_examples 'Duplicated Join Table' do
      it 'should raise error with proper message' do
        expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError)
      end
    end

    shared_examples 'Join Table update with the same resource after previous effective at' do
      it { expect { subject }.to change { join_table_class.count }.by(-1) }
      it { expect { subject }.to change { join_table_resource.reload.effective_at } }
      it do
        expect { subject }
          .to change { join_table_class.exists?(second_resource_tables.last.id) }.to false
      end
    end

    shared_examples 'Join Table update with the same resource after previous effective at 2' do
      it { expect { subject }.not_to change { join_table_class.count } }
      it { expect { subject }.to change { join_table_resource.reload.effective_at } }
      it do
        expect { subject }
          .not_to change { join_table_class.exists?(second_resource_tables.last.id) }
      end
    end

    shared_examples 'Join Table update with the same resource after new effective_at' do
      it { expect { subject }.to change { join_table_class.count }.by(-2) }
      it { expect { subject }.to change { join_table_resource.reload.effective_at } }
      it do
        expect { subject }
          .to change { join_table_class.exists?(second_resource_tables.last.id) }.to false
      end
      it do
        expect { subject }
          .to change { join_table_class.exists?(first_resource_tables.first.id) }.to false
      end
    end

    shared_examples 'Join Table update with the same resource after new effective_at 2' do
      it { expect { subject }.not_to change { join_table_class.count } }
      it { expect { subject }.to change { join_table_resource.reload.effective_at } }
      it do
        expect { subject }
          .not_to change { join_table_class.exists?(second_resource_tables.last.id) }
      end
      it do
        expect { subject }
          .not_to change { join_table_class.exists?(first_resource_tables.first.id) }
      end
    end

    shared_examples 'Join Table update with the same resource after and before new effective at' do
      it { expect { subject }.to change { join_table_class.count }.by(-4) }
      it do
        expect { subject }.to change { join_table_class.exists?(join_table_resource.id) }.to false
      end
      it do
        expect { subject }.to change { join_table_class.exists?(third_resource_table.id) }.to false
      end
      it do
        expect { subject }
          .to change { join_table_class.exists?(second_resource_tables.last.id) }.to false
      end
      it do
        expect { subject }
          .to change { join_table_class.exists?(first_resource_tables.first.id) }.to false
      end
    end

    shared_examples 'Join Table update with the same resource after and before new effective at 2' do
      it { expect { subject }.to change { join_table_class.count }.by(-1) }
      it do
        expect { subject }.not_to change { join_table_class.exists?(join_table_resource.id) }
      end
      it do
        expect { subject }.to change { join_table_class.exists?(third_resource_table.id) }.to false
      end
      it do
        expect { subject }
          .not_to change { join_table_class.exists?(second_resource_tables.last.id) }
      end
      it do
        expect { subject }
          .not_to change { join_table_class.exists?(first_resource_tables.first.id) }
      end
    end

    context 'for EmployeeWorkingPlace' do
      before do
        create(:employee_working_place,
          employee: employee, effective_at: employee.events.first.effective_at)
      end

      let(:resource_class) { WorkingPlace }
      let(:join_table_class) { EmployeeWorkingPlace }
      let(:resource) { create(:working_place, account: Account.current) }

      context 'JoinTable create' do
        let(:resource_params) { { working_place_id: resource.id } }
        let!(:existing_join_table) do
          create(:employee_working_place, effective_at: '1/4/2015', employee: employee)
        end

        it_behaves_like 'Join Table create'

        context 'when there is Join Table with the same resource and date' do
          let(:resource_params) { { working_place_id: existing_join_table.working_place_id } }

          it_behaves_like 'Duplicated Join Table'
        end

        context 'when there is contract_end assigned and no reset working_place' do
          before do
            employee.employee_working_places.map(&:destroy)
            event_params = {
              effective_at: Time.zone.parse('2016/03/01'),
              event_type: 'contract_end',
              employee: { id: employee.id }
            }
            CreateEvent.new(event_params, {}).call
            subject
          end

          it { expect(employee.employee_working_places.count).to eq(2) }
          it { expect(employee.reload.working_places.where(reset: true).exists?).to be(true) }
        end

        context 'when there is JoinTable with the same reosurce assigned before' do
          let!(:same_resource_before) do
            create(:employee_working_place,
              effective_at: '1/3/2015', employee: employee, working_place: resource)
          end

          it { expect { subject }.to_not raise_error }

          it { expect { subject }.to change { join_table_class.exists?(existing_join_table.id) } }
          it { expect { subject }.to change { join_table_class.count }.by(-1) }

          it { expect(subject[:result].effective_at).to eq same_resource_before.effective_at }
          it { expect(subject[:result].id).to eq same_resource_before.id }
          it { expect(subject[:status]).to eq 205 }
        end

        context 'when there is JoinTable with the same resource assigned' do
          let!(:same_resource_after) do
            create(:employee_working_place,
              effective_at: '1/5/2015', employee: employee, working_place: resource)
          end

          context 'after effective_at' do
            it_behaves_like 'Join Table create that doesnt allow same resource one after another'

            it { expect { subject }.to change { join_table_class.count }.by(-1) }

            it { expect(subject[:result].effective_at).to eq params[:effective_at].to_date }
            it { expect(subject[:status]).to eq 201 }
          end

          context 'before and after effective_at' do
            let!(:same_resource_before) do
              create(:employee_working_place,
                employee: employee, working_place: resource, effective_at: '1/3/2015')
            end

            it_behaves_like  'Join Table create that doesnt allow same resource one after another'

            it { expect { subject }.to change { join_table_class.count }.by(-2) }

            it { expect(subject[:result].effective_at).to eq same_resource_before.effective_at }
            it { expect(subject[:result].id).to eq same_resource_before.id }
            it { expect(subject[:status]).to eq 205 }
          end
        end

        context 'when there is table with other resource' do
          before { params[:effective_at] = 2.years.ago.to_s }

          it_behaves_like 'Join Table create with different resource after and effective till in past'

          context 'and effective till is in the future' do
            before { existing_join_table.update!(effective_at: 2.years.since) }

            it_behaves_like 'Join Table create with different resource after, after Time now'
          end
        end
      end

      context 'Join Table Update' do
        before { employee.employee_working_places.reload }
        let(:resource_params) { {} }
        let(:second_resource) { create(:working_place, account: Account.current) }
        let(:third_resource) { create(:working_place, account: Account.current) }
        let(:join_table_resource) { first_resource_tables.last }
        let!(:first_resource_tables) do
          [2.years.ago, Time.now].map do |date|
            create(:employee_working_place,
              employee: employee, effective_at: date,
              working_place:
                employee.employee_working_places.order(:effective_at).first.working_place)
          end
        end
        let!(:second_resource_tables) do
          [1.year.ago, 1.year.since].map do |date|
            create(:employee_working_place,
              employee: employee, effective_at: date, working_place: second_resource)
          end
        end
        let!(:third_resource_table) do
          create(:employee_working_place,
            employee: employee, effective_at: 3.years.ago, working_place: third_resource)
        end

        context 'when after old effective at is the same resource' do
          before { params[:effective_at] = 5.years.since.to_s }

          it_behaves_like 'Join Table update with the same resource after previous effective at'
        end

        context 'when there is the same resource after new effective_at' do
          before { params[:effective_at] = (2.years.ago - 2.months).to_s }

          it_behaves_like 'Join Table update with the same resource after new effective_at'
        end

        context 'where there is the same resource after and before new effective_at' do
          before { params[:effective_at] = 3.years.ago.to_s }

          it_behaves_like 'Join Table update with the same resource after and before new effective at'
        end
      end
    end

    context 'for EmployeeTimeOffPolicy' do
      let(:category) { create(:time_off_category, account: Account.current) }
      let(:resource) { create(:time_off_policy, time_off_category: category) }
      let(:existing_resource) { create(:time_off_policy, time_off_category: category) }
      let(:resource_params) { { time_off_policy_id: resource.id } }
      let(:resource_class) { TimeOffPolicy }
      let(:join_table_class) { EmployeeTimeOffPolicy }
      let!(:existing_join_table) do
        create(:employee_time_off_policy, :with_employee_balance,
          effective_at: '1/4/2015', employee: employee, time_off_policy: existing_resource)
      end

      context 'Join table create' do
        context 'when before is Join Table with different resource' do
          let!(:resource_before) do
            create(:employee_time_off_policy, :with_employee_balance,
              employee: employee, effective_at: params[:effective_at].to_date - 1.week,
              time_off_policy: policy)
          end

          context 'in different category' do
            let(:policy) do
              create(:time_off_policy,
                time_off_category: create(:time_off_category, account: Account.current))
            end

            it { expect { subject }.to_not raise_error }
            it { expect(subject[:status]).to eq 201 }
          end

          context 'in the same category' do
            let(:policy) { create(:time_off_policy, time_off_category: category) }

            it { expect { subject }.to_not raise_error }
            it { expect(subject[:status]).to eq 201 }
          end
        end

        it_behaves_like 'Join Table create'

        context 'when there is contract_end assigned and no reset time_off_policy' do
          before do
            employee.employee_time_off_policies.map(&:destroy)
            employee.employee_balances.map(&:destroy)
            event_params = {
              effective_at: Time.zone.parse('2016/03/01'),
              event_type: 'contract_end',
              employee: { id: employee.reload.id }
            }
            CreateEvent.new(event_params, {}).call
            subject
          end

          it { expect(employee.employee_time_off_policies.count).to eq(2) }
          it { expect(employee.reload.time_off_policies.where(reset: true).exists?).to be(true) }
        end

        context 'when there is Join Table with the same resource and date' do
          let(:resource_params) { { time_off_policy_id: existing_join_table.time_off_policy_id } }

          it_behaves_like 'Duplicated Join Table'
        end

        context 'when there is JoinTable with the same reosurce assigned before' do
          let!(:same_resource_before) do
            create(:employee_time_off_policy, :with_employee_balance,
              effective_at: '1/3/2015', employee: employee, time_off_policy: resource)
          end

          it { expect { subject }.to change { Employee::Balance.count }.by(-1) }
          it { expect { subject }.to_not raise_error }

          it { expect { subject }.to change { join_table_class.exists?(existing_join_table.id) } }
          it { expect { subject }.not_to change { join_table_class.count } }

          it { expect(subject[:status]).to eq 201 }
        end

        context 'when there is JoinTable with the same resource assigned' do
          let!(:same_resource_after) do
            create(:employee_time_off_policy, :with_employee_balance,
              effective_at: '1/5/2015', employee: employee, time_off_policy: resource)
          end

          it { expect { subject }.to change { Employee::Balance.count }.by(-1) }

          it { expect { subject }.to_not raise_error }

          it { expect { subject }.not_to change { join_table_class.count } }
          it { expect { subject }.to change { join_table_class.exists?(existing_join_table.id) } }
          it { expect { subject }.not_to change { join_table_class.exists?(same_resource_after.id) } }

          it { expect(subject[:result].effective_at).to eq params[:effective_at].to_date }
          it { expect(subject[:status]).to eq 201 }

          context 'before and after effective_at' do
            let!(:same_resource_before) do
              create(:employee_time_off_policy, :with_employee_balance,
                employee: employee, time_off_policy: resource, effective_at: '1/3/2015')
            end

            it { expect { subject }.to change { Employee::Balance.count }.by(-1) }

            it { expect { subject }.to_not raise_error }
            it { expect { subject }.not_to change { join_table_class.count } }
            it { expect { subject }.to change { join_table_class.exists?(existing_join_table.id) } }
            it { expect { subject }.not_to change { join_table_class.exists?(same_resource_after.id) } }

            it { expect(subject[:status]).to eq 201 }
          end
        end

        context 'when there is table with other resource' do
          before { params[:effective_at] = 2.years.ago.to_s }

          it { expect { subject }.to_not change { Employee::Balance.count } }
          it_behaves_like 'Join Table create with different resource after and effective till in past'

          context 'and effective till is in the future' do
            before { existing_join_table.update!(effective_at: 2.years.since) }

            it { expect { subject }.to_not change { Employee::Balance.count } }
            it_behaves_like 'Join Table create with different resource after, after Time now'
          end
        end
      end

      context 'Join Table Update' do
        before do
          assignation_balance = existing_join_table.policy_assignation_balance
          existing_join_table.update!(effective_at: 4.years.ago)
          assignation_balance.update!(
            effective_at: 4.years.ago + Employee::Balance::ASSIGNATION_OFFSET
          )
        end
        let(:join_table_resource) { first_resource_tables.last }
        let(:resource_params) { {} }
        let(:second_resource) do
          create(:time_off_policy,
            time_off_category: existing_resource.time_off_category)
        end
        let!(:first_resource_tables) do
          [2.years.ago, Time.now].map do |date|
            create(:employee_time_off_policy, :with_employee_balance,
              employee: employee, effective_at: date, time_off_policy: existing_resource)
          end
        end
        let!(:second_resource_tables) do
          [1.year.ago, 1.year.since].map do |date|
            create(:employee_time_off_policy, :with_employee_balance,
              employee: employee, effective_at: date, time_off_policy: second_resource)
          end
        end
        let!(:third_resource_table) do
          create(:employee_time_off_policy, :with_employee_balance,
            employee: employee, effective_at: 3.years.ago,
            time_off_policy: create(:time_off_policy, time_off_category: category))
        end

        context 'when resource is before employee\'s hired date' do
          before do
            allow_any_instance_of(Employee::Event).to receive(:valid?) { true }
            employee.events.first.update!(effective_at: 4.years.ago + 1.week)
            params[:effective_at] = employee.hired_date
          end
          let!(:assignation_balance) { join_table_resource.policy_assignation_balance }
          let(:join_table_resource) { existing_join_table }

          it { expect { subject }.to change { join_table_resource.reload.effective_at } }
          it { expect { subject }.to change { assignation_balance.reload.effective_at } }
        end

        context 'when after old effective at is the same resource' do
          before { params[:effective_at] = 5.years.since.to_s }

          it { expect { subject }.not_to change { Employee::Balance.count } }

          it { expect { subject }.not_to change { join_table_class.count } }
          it { expect { subject }.to change { join_table_resource.reload.effective_at } }
          it do
            expect { subject }
              .not_to change { join_table_class.exists?(second_resource_tables.last.id) }
          end
        end

        context 'when there is the same resource after new effective_at' do
          before { params[:effective_at] = (2.years.ago - 2.months).to_s }

          it { expect { subject }.not_to change { Employee::Balance.count } }

          it { expect { subject }.not_to change { join_table_class.count } }
          it { expect { subject }.to change { join_table_resource.reload.effective_at } }
          it do
            expect { subject }
              .not_to change { join_table_class.exists?(second_resource_tables.last.id) }
          end
          it do
            expect { subject }
              .not_to change { join_table_class.exists?(first_resource_tables.first.id) }
          end
        end

        context 'where there is the same resource after and before new effective_at' do
          before { params[:effective_at] = 3.years.ago.to_s }

          it { expect { subject }.to change { Employee::Balance.count }.by(-1) }

          it { expect { subject }.to change { join_table_class.count }.by(-1) }
          it do
            expect { subject }.not_to change { join_table_class.exists?(join_table_resource.id) }
          end
          it do
            expect { subject }.to change { join_table_class.exists?(third_resource_table.id) }.to false
          end
          it do
            expect { subject }
              .not_to change { join_table_class.exists?(second_resource_tables.last.id) }
          end
          it do
            expect { subject }
              .not_to change { join_table_class.exists?(first_resource_tables.first.id) }
          end
        end
      end
    end

    context 'for EmployeePresencePolicy' do
      let(:resource) { create(:presence_policy, :with_presence_day, account: Account.current) }
      let(:resource_params) { { presence_policy_id: resource.id, order_of_start_day: 3 } }
      let(:resource_class) { PresencePolicy }
      let(:join_table_class) { EmployeePresencePolicy }
      let!(:existing_join_table) do
        create(:employee_presence_policy, effective_at: '1/4/2015', employee: employee)
      end

      context 'Join table create' do
        it_behaves_like 'Join Table create'

        context 'when there is contract_end assigned and no reset presence_policy' do
          before do
            employee.employee_presence_policies.map(&:destroy)
            event_params = {
              effective_at: Time.zone.parse('2016/03/01'),
              event_type: 'contract_end',
              employee: { id: employee.id }
            }
            CreateEvent.new(event_params, {}).call
            subject
          end

          it { expect(employee.employee_presence_policies.count).to eq(2) }
          it { expect(employee.reload.presence_policies.where(reset: true).exists?).to be(true) }
        end

        context 'when there is Join Table with the same resource and date' do
          let(:resource_params) { { presence_policy_id: existing_join_table.presence_policy_id } }

          it_behaves_like 'Duplicated Join Table'
        end

        context 'when there is JoinTable with the same reosurce assigned before' do
          let!(:same_resource_before) do
            create(:employee_presence_policy,
              effective_at: '1/3/2015', employee: employee, presence_policy: resource)
          end

          it { expect { subject }.to_not raise_error }

          it { expect { subject }.to change { join_table_class.exists?(existing_join_table.id) } }
          it { expect { subject }.not_to change { join_table_class.count } }

          it { expect(subject[:result].effective_at).to eq existing_join_table.effective_at }
          it { expect(subject[:result].id).not_to eq same_resource_before.id }
          it { expect(subject[:status]).to eq 201 }
        end

        context 'when there is JoinTable with the same reosurce assigned' do
          let!(:same_resource_after) do
            create(:employee_presence_policy,
              effective_at: '1/5/2015', employee: employee, presence_policy: resource)
          end

          it_behaves_like 'Join Table create that allows same resource one after another'

          it { expect(subject[:result].effective_at).to eq params[:effective_at].to_date }

          context 'before and after effective_at' do
            let!(:same_resource_before) do
              create(:employee_presence_policy,
                employee: employee, presence_policy: resource, effective_at: '1/3/2015')
            end

            it_behaves_like 'Join Table create that allows same resource one after another'

            it { expect(subject[:result].effective_at).to eq existing_join_table.effective_at }
            it { expect(subject[:result].id).not_to eq same_resource_before.id }
          end
        end

        context 'when there is table with other resource' do
          before { params[:effective_at] = 2.years.ago.to_s }

          it_behaves_like 'Join Table create with different resource after and effective till in past'

          context 'and effective_till is in the future' do
            before { existing_join_table.update!(effective_at: 2.years.since) }

            it_behaves_like 'Join Table create with different resource after, after Time now'
          end
        end
      end

      context 'Join Table Update' do
        before { existing_join_table.update!(effective_at: 4.years.ago) }
        let(:resource_params) { {} }
        let(:second_resource) { create(:presence_policy, :with_presence_day, account: Account.current) }
        let(:third_resource) { create(:presence_policy, :with_presence_day, account: Account.current) }
        let(:join_table_resource) { first_resource_tables.last }
        let!(:first_resource_tables) do
          [2.years.ago, Time.now].map do |date|
            create(:employee_presence_policy, employee: employee, effective_at: date,
                                              presence_policy: existing_join_table.presence_policy)
          end
        end
        let!(:second_resource_tables) do
          [1.year.ago, 1.year.since].map do |date|
            create(:employee_presence_policy, employee: employee, effective_at: date,
                                              presence_policy: second_resource)
          end
        end
        let!(:third_resource_table) do
          create(:employee_presence_policy, employee: employee, effective_at: 3.years.ago,
                                            presence_policy: third_resource)
        end

        context 'when after old effective at is the same resource' do
          before { params[:effective_at] = 5.years.since.to_s }

          it_behaves_like 'Join Table update with the same resource after previous effective at 2'
        end

        context 'when there is the same resource after new effective_at' do
          before { params[:effective_at] = (2.years.ago - 2.months).to_s }

          it_behaves_like 'Join Table update with the same resource after new effective_at 2'
        end

        context 'where there is the same resource after and before new effective_at' do
          before { params[:effective_at] = 3.years.ago.to_s }

          it_behaves_like 'Join Table update with the same resource after and before new effective at 2'
        end
      end
    end

    context 'with contract_end' do
      let(:now) { Time.zone.now }
      let(:time_off_category) { create(:time_off_category, account: Account.current) }
      let(:time_off_policy)   { create(:time_off_policy, time_off_category: time_off_category) }
      let!(:etop) { create(:employee_time_off_policy, employee: employee, effective_at: now, time_off_policy: time_off_policy) }
      let!(:epp)  { create(:employee_presence_policy, employee: employee, effective_at: now) }
      let!(:ewp)  { create(:employee_working_place, employee: employee, effective_at: now) }
      let!(:contract_end) do
        create(:employee_event, effective_at: now + 3.months, employee: employee,
          event_type: 'contract_end')
      end
      let!(:rehire) do
        create(:employee_event, effective_at: contract_end.effective_at + 1.days, employee: employee,
          event_type: 'hired')
      end

      context 'when moving join table from current hire period' do
       context 'when moving after current contract_end_date' do
          let!(:contract_end_2) do
            create(:employee_event, effective_at: contract_end.effective_at + 6.months,
              employee: employee, event_type: 'contract_end')
          end

          let(:join_table_resource) { epp }
          let(:params_effective_at) { contract_end.effective_at + 2.months }
          let(:join_table_class)    { EmployeePresencePolicy }
          let(:resource_class)      { PresencePolicy }
          let(:resource_params)     {{}}
          let(:policies_dates)      { employee.employee_presence_policies.pluck(:effective_at) }
          let(:expected_dates)      { [params_effective_at, contract_end_2.effective_at + 1.day] }

          before { subject }

          it { expect(policies_dates).to match_array(expected_dates) }
       end

       context 'when moving before current hire_date' do
          let!(:contract_end_2) do
            create(:employee_event, effective_at: contract_end.effective_at + 6.months,
              employee: employee, event_type: 'contract_end')
          end

          let!(:join_table_resource) { create(:employee_presence_policy, employee: employee, effective_at: contract_end_2.effective_at - 1.month) }
          let(:params_effective_at)  { contract_end.effective_at - 2.months }
          let(:join_table_class)     { EmployeePresencePolicy }
          let(:resource_class)       { PresencePolicy }
          let(:resource_params)      {{}}
          let(:policies_dates)       { employee.employee_presence_policies.pluck(:effective_at) }
          let(:expected_dates)       { [params_effective_at, contract_end.effective_at + 1.day] }

          before do
            epp.destroy
            employee.employee_presence_policies.with_reset.find_by(effective_at: contract_end.effective_at + 1.day).destroy
            subject
          end

          it { expect(policies_dates).to match_array(expected_dates) }
       end
      end

      context 'when rehire day after contract_end' do
        let(:params_effective_at) { rehire.effective_at }

        context 'for EmployeeTimeOffPolicy' do
          let(:same_resource_before) { etop }
          let(:existing_join_table)  { employee.employee_time_off_policies.with_reset.first }
          let(:resource_class)       { TimeOffPolicy }
          let(:join_table_class)     { EmployeeTimeOffPolicy }

          context 'when assigning different EmployeeTimeOffPolicy' do
            let!(:top) { create(:time_off_policy, time_off_category: etop.time_off_category) }
            let(:resource_params) { { time_off_policy_id: top.id } }

            it_behaves_like 'Join Table create with different resource before and contract_end'
          end

          context 'when assigning the same EmployeeTimeOffPolicy' do
            let(:resource_params) { { time_off_policy_id: same_resource_before.time_off_policy_id } }

            it_behaves_like 'Join Table create'
          end

          context 'when moving assigned policy from day after contract_end' do
            let(:top) { create(:time_off_policy, time_off_category: time_off_category, policy_type: time_off_policy.policy_type) }
            let!(:join_table_resource) do
              create(:employee_time_off_policy, employee: employee, time_off_policy: top, effective_at: rehire.effective_at)
            end
            let(:params_effective_at) { rehire.effective_at + 1.month - 1.day }
            let(:resource_params) {{}}

            context 'employee have proper resources' do
              before { subject }

              it { expect(employee.employee_time_off_policies.count).to eq(3) }
              it { expect(employee.employee_time_off_policies.with_reset.count).to eq(1) }
              it 'returns policies in proper dates' do
                dates = employee.reload.employee_time_off_policies.map { |etop| etop.effective_at.to_date }
                expected_dates = ['01/01/2016', '02/04/2016', '01/05/2016'].map(&:to_date)
                expect(dates).to match_array(expected_dates)
              end
            end

            it { expect { subject }.to change(EmployeeTimeOffPolicy, :count).by(1) }
          end
        end

        context 'for EmployeePresencePolicy' do
          let(:same_resource_before) { epp }
          let(:existing_join_table)  { employee.employee_presence_policies.with_reset.first }
          let(:resource_class)       { PresencePolicy }
          let(:join_table_class)     { EmployeePresencePolicy }

          context 'when assigning different EmployeePresencePolicy' do
            let!(:presence_policy) { create(:presence_policy, :with_presence_day) }
            let(:resource_params) { { presence_policy_id: presence_policy.id } }

            it_behaves_like 'Join Table create with different resource before and contract_end'
          end

          context 'when assigning the same EmployeePresencePolicy' do
            let(:resource_params) { { presence_policy_id: same_resource_before.presence_policy_id } }

            it_behaves_like 'Join Table create'
          end

          context 'when moving assigned policy from day after contract_end' do
            let!(:presence_policy) { create(:presence_policy, :with_presence_day) }
            let!(:join_table_resource) do
              create(:employee_presence_policy, employee: employee, presence_policy: presence_policy,
                effective_at: rehire.effective_at)
            end
            let(:params_effective_at) { rehire.effective_at + 1.month - 1.day }
            let(:resource_params) {{}}

            context 'employee have proper resources' do
              before { subject }

              it { expect(employee.employee_presence_policies.count).to eq(3) }
              it { expect(employee.employee_presence_policies.with_reset.count).to eq(1) }
              it 'returns policies in proper dates' do
                dates = employee.employee_presence_policies.map { |epp| epp.effective_at.to_date }
                expected_dates = ['01/01/2016', '02/04/2016', '01/05/2016'].map(&:to_date)
                expect(dates).to match_array(expected_dates)
              end
            end

            it { expect { subject }.to change(EmployeePresencePolicy, :count).by(1) }
          end
        end

        context 'for EmployeeWorkingPlace' do
          let(:same_resource_before) { ewp }
          let(:existing_join_table)  { employee.employee_working_places.with_reset.first }
          let(:resource_class)       { WorkingPlace }
          let(:join_table_class)     { EmployeeWorkingPlace }

          context 'when assigning different EmployeeWorkingPlace' do
            let!(:working_place) { create(:working_place) }
            let(:resource_params) { { working_place_id: working_place.id } }

            it_behaves_like 'Join Table create with different resource before and contract_end'
          end

          context 'when assigning the same EmployeeWorkingPlace' do
            let(:resource_params) { { working_place_id: same_resource_before.working_place_id } }

            it_behaves_like 'Join Table create'
          end

          context 'when moving assigned working place from day after contract_end' do
            let!(:working_place) { create(:working_place, account: Account.current) }
            let!(:join_table_resource) do
              create(:employee_working_place, employee: employee, working_place: working_place,
                effective_at: rehire.effective_at)
            end
            let(:params_effective_at) { rehire.effective_at + 1.month - 1.day }
            let(:resource_params) {{}}

            context 'employee have proper resources' do
              before { subject }

              it { expect(employee.employee_working_places.count).to eq(3) }
              it { expect(employee.employee_working_places.with_reset.count).to eq(1) }
              it 'returns policies in proper dates' do
                dates = employee.employee_working_places.map { |ewp| ewp.effective_at.to_date }
                expected_dates = ['01/01/2016', '02/04/2016', '01/05/2016'].map(&:to_date)
                expect(dates).to match_array(expected_dates)
              end
            end

            it { expect { subject }.to change(EmployeeWorkingPlace, :count).by(1) }
          end
        end
      end
    end
  end
end
