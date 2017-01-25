require 'rails_helper'

RSpec.describe do
  include_context 'shared_context_account_helper'
  include_context 'shared_context_timecop_helper'

  before do
    Account.current = employee.account
    Account::User.current = create(:account_user, account: employee.account)
  end
  subject { UpdateEvent.new(params, employee_attributes_params).call }
  let(:first_name_order) { 1 }
  let(:employee) { create(:employee, :with_attributes) }
  let(:event) { employee.events.first }
  let(:event_id) { event.id }
  let(:first_attribute) { event.employee_attribute_versions.first }
  let(:second_attribute) { event.employee_attribute_versions.last }
  let(:effective_at) { Time.now - 2.years }
  let(:first_name_value) { 'John' }
  let(:event_type) { 'hired' }
  let(:employee_id) { employee.id }
  let(:params) do
    {
      id: event_id,
      effective_at: effective_at,
      event_type: event_type,
      comment: 'comment',
      employee: {
        id: employee_id
      }
    }
  end
  let(:employee_attributes_params) do
    [
      {
        value: 'Snow',
        id: first_attribute.id,
        attribute_name: first_attribute.attribute_definition.name
      },
      {
        value: 'Stark',
        id: second_attribute.id,
        attribute_name: second_attribute.attribute_definition.name
      },
      {
        value: first_name_value,
        attribute_name: 'firstname',
        order: first_name_order
      }
    ]
  end

  context 'with valid params' do
    let!(:definition) do
      create(:employee_attribute_definition,
        account: employee.account, name: 'firstname', multiple: true, validation: { presence: true })
    end

    context 'when attributes id send' do
      it { expect { subject }.to change { event.employee_attribute_versions.count }.by(1) }
      it { expect { subject }.to change { first_attribute.reload.data.value }.to eq 'Snow' }
      it { expect { subject }.to change { second_attribute.reload.data.value }.to eq 'Stark' }
    end

    context 'for profile picture' do
      let(:employee_file) { create(:employee_file) }
      let(:employee_file_id) { employee_file.id }
      let(:file_path) { ["#{Rails.root}/spec/fixtures/files/test.jpg"] }
      let!(:picture_definition) do
        create(:employee_attribute_definition,
          name: 'profile_picture', account: employee.account, attribute_type: 'File')
      end
      let!(:picture_version) do
        create(:employee_attribute_version,
          employee: employee, employee_event_id: event.id, attribute_definition: picture_definition)
      end

      before do
        allow_any_instance_of(EmployeeFile).to receive(:find_file_path) { file_path }
        employee_attributes_params.push(
          {
            type: 'employee_attribute',
            attribute_name: 'profile_picture',
            value: employee_file_id,
            id: picture_version.id
          }
        )
      end

      context 'when version does not have picture assigned' do
        it { expect { subject }.to change { picture_version.reload.data.file_type } }
        it { expect { subject }.to change { picture_version.reload.data.size } }
        it { expect { subject }.to change { picture_version.reload.data.id } }
      end

      context 'when version has already picture assigned' do
        let(:file_path) { ["#{Rails.root}/spec/fixtures/files/test.jpg", "test_route"] }

        before do
          picture_version[:data][:id] = employee_file.id
          picture_version.save
        end

        context 'when more than one picture in file folder' do
          context 'and the same picture send for version in params' do
            it { expect { subject }.to_not change { picture_version.reload.data.id } }
            it { expect { subject }.to_not raise_error }
          end

          context 'and different picture send for version in params' do
            let(:employee_file_id) { create(:employee_file).id }

            it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
          end
        end

        context 'when no pictures in file folder' do
          let(:file_path) { [] }

          context 'and the same picture send for version in params' do
            it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
          end

          context 'and different picture send for version in params' do
            it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
          end
        end
      end
    end

    context 'when not all event attributes send' do
      before { employee_attributes_params.shift(2) }

      it { expect { subject }.to change { event.employee_attribute_versions.count }.by(-1) }
    end

    context 'forbbiden attributes' do
      before do
        employee_attributes_params.pop
        event.reload.employee_attribute_versions
        definition.update!(validation: nil)
      end
      let!(:salary_attribute) do
        create(:employee_attribute_version,
          employee: employee, attribute_definition: salary_definition, data: { line: '2000' },
          event: event)
      end
      let!(:salary_definition) do
        create(:employee_attribute_definition,
          account: employee.account, name: 'annual_salary', validation: { presence: true })
      end

      context 'when account manager updates event' do
        before { Account::User.current.update!(role: 'account_administrator') }

        context 'and forbiden attribute is send' do
          before do
            employee_attributes_params.push(
              { value: 3000, attribute_name: 'annual_salary', id: salary_attribute.id }
            )
          end

          it { expect { subject }.to_not change { event.employee_attribute_versions.count } }
          it { expect { subject }.to change { first_attribute.reload.data.value }.to eq 'Snow' }
          it { expect { subject }.to change { second_attribute.reload.data.value }.to eq 'Stark' }
          it { expect { subject }.to change { salary_attribute.reload.data.value }.to eq '3000' }
        end

        context 'and forbiden attribute is not send' do
          it { expect { subject }.to change { event.employee_attribute_versions.count }.by(-1) }
          it { expect { subject }.to change { first_attribute.reload.data.value }.to eq 'Snow' }
          it { expect { subject }.to change { second_attribute.reload.data.value }.to eq 'Stark' }
          it 'should destroy salary attribute' do
            expect { subject }.to change {
              Employee::AttributeVersion.exists?(salary_attribute.id)
            }.to false
          end
        end
      end

      context 'when employee who is not an account manager updates event' do
        context 'and he only does not send forbiddean version' do
          it { expect { subject }.to change { first_attribute.reload.data.value }.to eq 'Snow' }
          it { expect { subject }.to change { second_attribute.reload.data.value }.to eq 'Stark' }
          it { expect { subject }.to_not change { event.employee_attribute_versions.count } }
          it 'should not destroy salary attribute' do
            expect { subject }.to_not change {
              Employee::AttributeVersion.exists?(salary_attribute.id)
            }
          end
        end

        context 'and he does not send a few params including forbiddean version' do
          let!(:firstname_attribute) do
            create(:employee_attribute_version,
              employee: employee, attribute_definition: definition, data: { string: 'test' },
              event: event, order: 1
            )
          end

          it { expect { subject }.to change { first_attribute.reload.data.value }.to eq 'Snow' }
          it { expect { subject }.to change { second_attribute.reload.data.value }.to eq 'Stark' }
          it { expect { subject }.to change { event.employee_attribute_versions.count }.by(-1) }
          it 'should destroy firstname attribute' do
            expect { subject }.to change {
              Employee::AttributeVersion.exists?(firstname_attribute.id)
            }.to false
          end
          it 'should not destroy salary attribute' do
            expect { subject }.to_not change {
              Employee::AttributeVersion.exists?(salary_attribute.id)
            }
          end
        end
      end
    end

    context 'when effective at changes' do
      before do
        versions = employee.reload.employee_attribute_versions
        versions.first.update!(attribute_definition: definition, data: { string: 'a' })
        employee.events.first.update!(effective_at: 2.years.ago + 1.day)
        employee_attributes_params.shift
        [[20, etops.first], [30, etops.last], [40, new_etop]].map do |manual_amount, etop|
          etop.policy_assignation_balance.update!(
            manual_amount: manual_amount, policy_credit_addition: false
          )
        end
      end

      let(:first_category) { create(:time_off_category, account: employee.account) }
      let(:second_category) { create(:time_off_category, account: employee.account) }
      let!(:ewp) do
        create(:employee_working_place, employee: employee, effective_at: 2.years.ago + 1.day)
      end
      let!(:etops) do
        [first_category, second_category].map do |category|
          create(:employee_time_off_policy, :with_employee_balance,
            employee: employee, effective_at: 2.years.ago + 1.day,
            time_off_policy:
              create(:time_off_policy, :with_end_date, time_off_category: category)
          )
        end
      end
      let!(:new_etop) do
        create(:employee_time_off_policy, :with_employee_balance,
          employee: employee, effective_at: 2.years.ago + 5.days,
          time_off_policy:
            create(:time_off_policy, :with_end_date,time_off_category: first_category)
        )
      end
      let!(:epp) do
        create(:employee_presence_policy, employee: employee, effective_at: 2.years.since)
      end
      let!(:first_balance) { etops.first.policy_assignation_balance }
      let!(:second_balance) { etops.last.policy_assignation_balance }
      let!(:newest_balance) { new_etop.policy_assignation_balance }
      let(:effective_at) { 1.year.since }

      context 'and this is event hired' do
        context 'and date move to the future' do
          it { expect { subject }.to change { event.reload.effective_at } }
          it { expect { subject }.to change { ewp.reload.effective_at } }
          it { expect { subject }.to change { etops.last.reload.effective_at } }
          it { expect { subject }.to change { new_etop.reload.effective_at } }
          it { expect { subject }.to change { newest_balance.reload.effective_at } }
          it { expect { subject }.to change { second_balance.reload.effective_at } }
          it do
            expect { subject }.to change { newest_balance.reload.policy_credit_addition }.to true
          end

          it { expect { subject }.to change { EmployeeTimeOffPolicy.exists?(etops.first.id) } }
          it { expect { subject }.to change { Employee::Balance.exists?(first_balance.id) } }
          it { expect { subject }.to change { Employee::Balance.count }.by(-1) }

          it { expect { subject }.to_not change { second_balance.reload.manual_amount } }
          it { expect { subject }.to_not change { newest_balance.reload.manual_amount } }
          it { expect { subject }.to_not change { epp.reload.effective_at } }

          context 'it does not change policy credit addition to true while not policy start date' do
            let(:effective_at) { 1.year.since + 1.day }

            it { expect { subject }.to_not change { newest_balance.reload.policy_credit_addition } }
          end
        end

        context 'and date move to the past' do
          before do
            EmployeeTimeOffPolicy.all.map do |etop|
              ManageEmployeeBalanceAdditions.new(etop).call
            end
            params[:effective_at] = 3.years.ago
          end

          it { expect { subject }.to change { event.reload.effective_at } }
          it { expect { subject }.to change { ewp.reload.effective_at } }
          it { expect { subject }.to change { etops.last.reload.effective_at } }
          it { expect { subject }.to change { etops.first.reload.effective_at } }
          it { expect { subject }.to change { first_balance.reload.effective_at } }
          it { expect { subject }.to change { second_balance.reload.effective_at } }
          it { expect { subject }.to change { Employee::Balance.additions.count }.by(4) }
          it { expect { subject }.to change { Employee::Balance.removals.count }.by(2) }
          it { expect { subject }.to change { Employee::Balance.count}.by(6) }

          it { expect { subject }.to_not change { first_balance.reload.manual_amount } }
          it { expect { subject }.to_not change { second_balance.reload.manual_amount } }
          it { expect { subject }.to_not change { newest_balance.reload.manual_amount } }
          it { expect { subject }.to_not change { new_etop.reload.effective_at } }
          it { expect { subject }.to_not change { newest_balance.reload.effective_at } }
          it { expect { subject }.to_not change { epp.reload.effective_at } }

          it { expect { subject }.to_not change { EmployeeTimeOffPolicy.exists?(etops.first.id) } }

          context 'it does not change policy credit addition to true while not policy start date' do
            let(:effective_at) { 3.years.ago + 1.day }

            it { expect { subject }.to_not change { newest_balance.reload.policy_credit_addition } }
          end
        end
      end

      context 'and this is not hired event' do
        let(:event_type) { 'change' }

        it { expect { subject }.to change { event.reload.effective_at } }
        it { expect { subject }.to_not change { ewp.reload.effective_at } }
        it { expect { subject }.to_not change { etops.last.reload.effective_at } }
        it { expect { subject }.to_not change { new_etop.reload.effective_at } }

        it { expect { subject }.to_not change { EmployeeTimeOffPolicy.exists?(etops.first.id) } }

        it { expect { subject }.to_not change { epp.reload.effective_at } }
      end

      context 'when there are employee balances between previous hired date and new hired date' do
        before do
          create(:time_off,
            start_time: employee.hired_date + 1.month,
            end_time: employee.hired_date + 2.months, employee: employee)
        end

        it { expect { subject }.to raise_error(ActiveRecord::RecordInvalid) }
      end
    end

    context 'when multiple attributes send' do
      before do
        employee_attributes_params.unshift(
          {
            value: 'ned',
            attribute_name: 'firstname',
            order: 2
          }
        )
      end

      it { expect { subject }.to change { event.employee_attribute_versions.count }.by(2) }
    end

    context 'when nested attribute send' do
      let!(:child_definition) do
        create(:employee_attribute_definition,
          account: employee.account, name: 'child', attribute_type: 'Child')
      end

      before do
        employee_attributes_params.unshift(
          {
            attribute_name: 'child',
            order: 2,
            value: {
              lastname: 'Stark',
              firstname: 'Arya'
            }
          }
        )
      end

      it { expect { subject }.to change { event.employee_attribute_versions.count }.by(2) }
      it 'has valid data' do
        subject
        expect(event.employee_attribute_versions.where(attribute_definition: child_definition)
          .first.data.value[:firstname]).to eq('Arya')
      end
    end
  end

  context 'contract_end' do
    let(:event_type) { 'contract_end' }
    let(:old_effective_at) { Time.zone.parse('2016/03/01') }
    let(:now) { Time.zone.now }
    let!(:category) { create(:time_off_category, account: Account.current) }
    let!(:top) { create(:time_off_policy, time_off_category: category) }
    let!(:etop) do
      create(:employee_time_off_policy, employee: employee, effective_at: now, time_off_policy: top)
    end
    let!(:epp) { create(:employee_presence_policy, employee: employee, effective_at: now) }
    let!(:ewp) { create(:employee_working_place, employee: employee, effective_at: now) }
    let!(:contract_end) do
      create(:employee_event, event_type: event_type, effective_at: old_effective_at,
        employee: employee)
    end
    let(:employee_contract_end) { employee.events.find_by(event_type: 'contract_end') }
    let(:event) { contract_end }
    let(:event_id) { contract_end.id }
    let(:employee_attributes_params) {{}}
    let(:reset_epp) { employee.employee_presence_policies.with_reset.last }
    let(:reset_ewp) { employee.employee_working_places.with_reset.last }
    let(:reset_etop) { employee.employee_time_off_policies.with_reset.last }

    context 'move to the future' do
      let(:effective_at) { Time.zone.parse('2016/04/01') }

      context 'when there is no re-hire' do
        it 'moves reset employee_presence_policies' do
          expect { subject }
            .to change { reset_epp.reload.effective_at }
            .from(old_effective_at + 1.day)
            .to(effective_at + 1.day)
        end

        it 'moves reset employee_working_places' do
          expect { subject }
            .to change { reset_ewp.reload.effective_at }
            .from(old_effective_at + 1.day)
            .to(effective_at + 1.day)
        end

        it 'moves reset employee_time_off_policies' do
          expect { subject }
            .to change { reset_etop.reload.effective_at }
            .from(old_effective_at + 1.day)
            .to(effective_at + 1.day)
        end
      end

      context 'moving after re-hire' do
        let!(:re_hire) do
          create(:employee_event, event_type: 'hired', effective_at: effective_at - 10.days,
            employee: employee)
        end

        it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
      end
    end

    context 'move to the past' do
      let(:effective_at) { Time.zone.parse('2012/01/01') }

      context 'there are no more join tables' do
        before do
          subject
          employee.reload
        end

        it { expect(employee_contract_end.effective_at).to eq(effective_at) }
        it { expect(employee.time_off_policies.count).to eq(0) }
        it { expect(employee.employee_time_off_policies.count).to eq(0) }
        it { expect(employee.presence_policies.count).to eq(0) }
        it { expect(employee.employee_presence_policies.count).to eq(0) }
        it { expect(employee.working_places.count).to eq(0) }
        it { expect(employee.employee_working_places.count).to eq(0) }
      end

      context 'there are join tables before new effective_at' do
        let!(:category2) { create(:time_off_category, account: Account.current) }
        let!(:top2) { create(:time_off_policy, time_off_category: category) }
        let!(:etop_2) do
          create(:employee_time_off_policy, :with_employee_balance, employee: employee,
            effective_at: effective_at - 9.days, time_off_policy: top2)
        end
        let!(:epp_2) do
          create(:employee_presence_policy, employee: employee, effective_at: effective_at - 9.days)
        end
        let!(:ewp_2) do
          create(:employee_working_place, employee: employee, effective_at: effective_at - 9.days)
        end

        context 'without time_off' do
          before do
            subject
            employee.reload
          end

          it { expect(employee_contract_end.effective_at).to eq(effective_at) }
          it { expect(employee.time_off_policies.count).to eq(2) }
          it { expect(employee.employee_time_off_policies.count).to eq(2) }
          it { expect(employee.employee_time_off_policies.with_reset.count).to eq(1) }
          it { expect(employee.presence_policies.count).to eq(2) }
          it { expect(employee.employee_presence_policies.count).to eq(2) }
          it { expect(employee.employee_presence_policies.with_reset.count).to eq(1) }
          it { expect(employee.working_places.count).to eq(2) }
          it { expect(employee.employee_working_places.count).to eq(2) }
          it { expect(employee.employee_working_places.with_reset.count).to eq(1) }
        end

        context 'with time_off' do
          let(:start_time) { effective_at - 10.days }

          let!(:time_off) do
            create(:time_off, start_time: start_time, end_time: end_time,
              employee: employee, time_off_category: category2)
          end

          context 'when moved before time_off start_time' do
            let(:start_time) { effective_at + 10.days }
            let(:end_time) { start_time + 10.days }

            it { expect { subject }.to change(TimeOff, :count).by(-1) }
          end

          context 'when moved before time_off end_time' do
            let(:end_time) { effective_at + 10.days }

            it 'moves it to day after contract_end' do
              expect { subject }
                .to change { time_off.reload.end_time }
                .from(end_time)
                .to(effective_at + 1.day)
            end
          end

          context 'when moved to time_off end_time' do
            let(:end_time) { effective_at + 10.days }

            it { expect { subject }.to_not change { time_off } }
          end
        end
      end
    end
  end

  context 'with invalid params' do
    let!(:definition) do
      create(:employee_attribute_definition,
        account: employee.account, name: 'firstname', multiple: true, validation: { presence: true })
    end

    context 'when required attribute does not send or value set to nil' do
      before do
        Employee::AttributeDefinition
          .where(name: 'firstname').first.update!(validation: { presence: true })
      end

      context 'when required attribute does not send' do
        before { employee_attributes_params.pop }

        it { expect { subject }.to raise_error(ActiveRecord::RecordInvalid) }
      end

      context 'when required attribute value set to nil' do
        let(:first_name_value) { nil }

        it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
      end
    end

    context 'when order does not send for multiple attribute' do
      let(:first_name_order) { nil }

      it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
    end

    context 'with invalid employee id' do
      let(:employee_id) { 'ab' }

      it { expect { subject }.to raise_error(ActiveRecord::RecordNotFound) }
    end

    context 'with invalid event id' do
      let(:event_id) { 'ab' }

      it { expect { subject }.to raise_error(ActiveRecord::RecordNotFound) }
    end
  end
end
