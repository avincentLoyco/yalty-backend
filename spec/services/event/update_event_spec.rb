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

          context 'and employee has employee balances' do
            before do
              EmployeeTimeOffPolicy.all.map do |etop|
                ManageEmployeeBalanceAdditions.new(etop).call
              end
            end

            context 'and hired date moved to etop start date' do
              it { expect { subject }.to change { EmployeeTimeOffPolicy.exists?(etops.first.id) } }
              it { expect { subject }.to change { Employee::Balance.exists?(first_balance.id) } }
              it { expect { subject }.to change { Employee::Balance.count }.by(-17) }
              it do
                expect { subject }.to change { Employee::Balance.pluck(:being_processed).uniq }
                  .to ([true])
              end
              it 'assignations have valid manual amount' do
                subject

                expect(etops.last.reload.policy_assignation_balance.manual_amount)
                  .to eq second_balance.manual_amount
                expect(new_etop.reload.policy_assignation_balance.manual_amount)
                  .to eq newest_balance.manual_amount
              end

              it 'assignations are policy credit additions' do
                subject

                expect(etops.last.reload.policy_assignation_balance.policy_credit_addition)
                  .to eq true
                expect(new_etop.reload.policy_assignation_balance.policy_credit_addition)
                  .to eq true
              end
            end

            context 'and hired date moved to not etop start date' do
              let(:effective_at) { 1.year.since - 1.day }

              it { expect { subject }.to change { EmployeeTimeOffPolicy.count }.by(-1) }
              it { expect { subject }.to change { Employee::Balance.exists?(first_balance.id) } }
              it { expect { subject }.to change { Employee::Balance.count }.by(-15) }
              it do
                expect { subject }.to change { Employee::Balance.pluck(:being_processed).uniq }
                  .to ([true])
              end
              it 'assignations have valid manual amount' do
                subject

                expect(etops.last.reload.policy_assignation_balance.manual_amount)
                  .to eq second_balance.manual_amount
                expect(new_etop.reload.policy_assignation_balance.manual_amount)
                  .to eq newest_balance.manual_amount
              end

              it 'assignations are policy credit additions' do
                subject

                expect(etops.last.reload.policy_assignation_balance.policy_credit_addition)
                  .to eq false
                expect(new_etop.reload.policy_assignation_balance.policy_credit_addition)
                  .to eq false
              end
            end
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
    let(:categories) { create_list(:time_off_category, 2, account: employee.account) }
    let(:policies) do
      categories.map do |category|
        create(:time_off_policy, :with_end_date, time_off_category: category)
      end
    end
    let!(:epp) do
      create(:employee_presence_policy, :with_time_entries,
        employee: employee, effective_at: 1.years.ago)
    end
    let!(:ewp) { create(:employee_working_place, employee: employee, effective_at: 1.years.ago) }
    let!(:etops) do
      policies.map do |policy|
        create(:employee_time_off_policy, :with_employee_balance,
          employee: employee, effective_at: 1.years.ago, time_off_policy: policy)
      end
    end
    let!(:time_offs) do
      [
        [1.year.ago - 2.days, 1.year.ago + 5.days], [4.months.ago, 4.months.ago + 3.days]
      ].map do |starts, ends|
        create(:time_off,
          employee: employee, start_time: starts, end_time: ends,
          time_off_category: categories.first)
      end
    end
    let!(:etop_assignation_balance) do
      create(:employee_balance_manual,
        employee: employee, time_off_category: time_offs.first.time_off_category,
        policy_credit_addition: true,
        effective_at:
          time_offs.first.start_time + Employee::Balance::START_DATE_OR_ASSIGNATION_OFFSET
      )
    end
    let!(:event) do
      create(:employee_event,
        employee: employee, event_type: 'contract_end', effective_at: Time.zone.today)
    end
    let(:employee_attributes_params) {{ }}
    let(:reset_balance_effective_at) { effective_at + 1.day + Employee::Balance::REMOVAL_OFFSET }
    before do
      time_offs.map do |time_off|
        validity_date =
          RelatedPolicyPeriod
            .new(time_off.employee_balance.employee_time_off_policy)
            .validity_date_for(time_off.end_time)
        UpdateEmployeeBalance.new(time_off.employee_balance, validity_date: validity_date).call
      end
      etops.map do |etop|
        validity_date = RelatedPolicyPeriod.new(etop).validity_date_for(etop.effective_at)
        UpdateEmployeeBalance.new(
          etop.policy_assignation_balance, validity_date: validity_date
        ).call
        ManageEmployeeBalanceAdditions.new(etop).call
      end
      subject
      event.reload
      employee.reload
    end

    context 'move to the future' do
      shared_examples 'Contract end in the future' do
        it { expect(event.effective_at).to eq effective_at }
        it { expect(employee.employee_time_off_policies.count).to eq(5) }
        it { expect(employee.employee_working_places.count).to eq(2) }
        it { expect(employee.employee_presence_policies.count).to eq(2) }
        it { expect(employee.time_offs.count).to eq (2) }
        it { expect(employee.employee_balances.where(reset_balance: true).count).to eq (2) }
        it do
          expect(time_offs.first.employee_balance.reload.validity_date.to_date)
            .to eq ('2016/4/1').to_date
        end
        it do
          expect(time_offs.last.employee_balance.reload.validity_date)
            .to eq reset_balance_effective_at
        end
        it do
          expect(employee.employee_balances.where(reset_balance: true)
            .pluck(:effective_at).uniq).to eq ([reset_balance_effective_at])
        end
      end

      context 'and contract end before policy start date' do
        let(:effective_at) { 1.year.since - 1.days }

        it { expect(employee.employee_balances.count).to eq (13) }
        it { expect(Employee::Balance.additions.count).to eq (5) }

        it_behaves_like 'Contract end in the future'
      end

      context 'when contract end in or after policy start date' do
        shared_examples 'Contract end in or after policy start date' do
          it { expect(Employee::Balance.additions.count).to eq (7) }
          it { expect(employee.employee_balances.count).to eq (17) }
        end

        context 'and contract end in policy start date' do
          let(:effective_at) { 1.year.since }

          it_behaves_like 'Contract end in or after policy start date'
          it_behaves_like 'Contract end in the future'
        end

        context 'and contract end after policy start date' do
          let(:effective_at) { 1.year.since + 3.days }

          it_behaves_like 'Contract end in or after policy start date'
          it_behaves_like 'Contract end in the future'
        end
      end
    end

    context 'move to the past' do
      context 'when all join tables effective at after contract end' do
        let(:effective_at) { 1.year.ago - 3.days }

        it { expect(event.effective_at).to eq effective_at }
        it { expect(employee.employee_time_off_policies.count).to eq(0) }
        it { expect(employee.employee_presence_policies.count).to eq(0) }
        it { expect(employee.employee_working_places.count).to eq(0) }
        it { expect(employee.employee_balances.count).to eq(0) }
        it { expect(employee.time_offs.count).to eq(0) }
      end

      context 'when all join tables effective at before or in contract end' do
        shared_examples 'Join tables effective_at before or in contract end' do
          it { expect(event.effective_at).to eq effective_at }
          it { expect(employee.employee_time_off_policies.count).to eq(5) }
          it { expect(employee.employee_working_places.count).to eq(2) }
          it { expect(employee.employee_presence_policies.count).to eq(2) }
          it { expect(employee.time_offs.count).to eq (1) }

          it { expect(employee.employee_balances.count).to eq (6) }
          it { expect(employee.employee_balances.where(reset_balance: true).count).to eq (2) }
          it do
            expect(employee.employee_balances.where(reset_balance: true)
              .pluck(:effective_at).uniq).to eq ([reset_balance_effective_at])
          end
          it do
            expect(time_offs.first.reload.employee_balance.validity_date)
              .to eq (reset_balance_effective_at)
          end

          it do
            etops.map do |etop|
              expect(etop.policy_assignation_balance.validity_date)
                .to eq (reset_balance_effective_at)
            end
          end
        end

        context 'in contract end date' do
          let(:effective_at) { 1.years.ago }

          it_behaves_like 'Join tables effective_at before or in contract end'
        end

        context 'before contract end' do
          let(:effective_at) { 1.years.ago + 1.day }

          it_behaves_like 'Join tables effective_at before or in contract end'
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
