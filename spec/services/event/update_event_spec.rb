require 'rails_helper'

RSpec.describe do
  include_context 'shared_context_account_helper'
  include_context 'shared_context_timecop_helper'
  include_context 'shared_context_remove_original_helper'

  before do
    Account.current = employee.account
    Account::User.current = create(:account_user, account: employee.account)
    employee.events.first.update!(effective_at: 2.years.ago - 2.days)
  end
  subject { UpdateEvent.new(params, employee_attributes_params).call }
  let(:first_name_order) { 1 }
  let(:employee) { create(:employee, :with_attributes) }
  let(:event) { employee.events.first }
  let(:event_id) { event.id }
  let(:first_attribute) { event.employee_attribute_versions.first }
  let(:second_attribute) { event.employee_attribute_versions.last }
  let(:effective_at) { Date.new(2015, 4, 21) }
  let(:first_name_value) { 'John' }
  let(:event_type) { 'hired' }
  let(:employee_id) { employee.id }
  let!(:presence_policy) do
    create(:presence_policy, :with_time_entries, account: employee.account, occupation_rate: 0.5)
  end
  let!(:occupation_rate_definition) do
    create(:employee_attribute_definition,
      name: 'occupation_rate',
      account: employee.account,
      attribute_type: Attribute::Number.attribute_type,
      validation: { range: [0, 1] })
  end
  let(:params) do
    {
      id: event_id,
      effective_at: effective_at,
      event_type: event_type,
      employee: {
        id: employee_id
      },
      presence_policy_id: presence_policy.id
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
      },
      {
        value: '0.5',
        attribute_name: 'occupation_rate'
      }
    ]
  end

  context 'with valid params' do
    let!(:definition) do
      create(:employee_attribute_definition,
        account: employee.account, name: 'firstname', multiple: true, validation: { presence: true })
    end

    context 'when attributes id send' do
      it { expect { subject }.to change { event.employee_attribute_versions.count }.by(2) }
      it { expect { subject }.to change { first_attribute.reload.data.value }.to eq 'Snow' }
      it { expect { subject }.to change { second_attribute.reload.data.value }.to eq 'Stark' }
    end

    context 'for profile picture' do
      let(:generic_file) { create(:generic_file) }
      let(:generic_file_id) { generic_file.id }
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
        allow_any_instance_of(GenericFile).to receive(:find_file_path) { file_path }
        employee_attributes_params.push(
          {
            type: 'employee_attribute',
            attribute_name: 'profile_picture',
            value: generic_file_id,
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
          picture_version[:data][:id] = generic_file.id
          picture_version.save
        end

        context 'when more than one picture in file folder' do
          context 'and the same picture send for version in params' do
            it { expect { subject }.to_not change { picture_version.reload.data.id } }
            it { expect { subject }.to_not raise_error }
          end

          context 'and different picture send for version in params' do
            let(:generic_file_id) { create(:generic_file).id }

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

      it { expect { subject }.to change { event.employee_attribute_versions.count }.by(0) }
    end

    context 'forbbiden attributes' do
      before do
        employee_attributes_params.reject! { |attr| attr[:attribute_name] == 'firstname' }
        event.reload.employee_attribute_versions
        definition.update!(validation: nil)
      end
      let!(:salary_attribute) do
        create(:employee_attribute_version,
          employee: employee, attribute_definition: salary_definition, data: { line: '2000' },
          event: event)
      end
      let!(:occupation_rate_attribute) do
        create(:employee_attribute_version,
          employee: employee, attribute_definition: occupation_rate_definition,
          data: { number: '0.5' }, event: event)
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
        if !employee_attributes_params.nil? &&
            employee_attributes_params.first[:attribute_name].eql?('firstname')
          employee_attributes_params.shift
        end
        [[20, etops.first], [30, etops.last], [40, new_etop]].map do |manual_amount, etop|
          etop.policy_assignation_balance.update!(
            manual_amount: manual_amount, balance_type: 'assignation'
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
      let(:effective_at) { 1.year.since + 2.days }

      context 'and this is event hired' do
        context 'and date move to the future' do
          it { expect { subject }.to change { event.reload.effective_at } }
          it { expect { subject }.to change { ewp.reload.effective_at } }
          it { expect { subject }.to change { etops.last.reload.effective_at } }
          it { expect { subject }.to change { new_etop.reload.effective_at } }
          it { expect { subject }.to change { newest_balance.reload.effective_at } }
          it { expect { subject }.to change { second_balance.reload.effective_at } }

          it { expect { subject }.to change { EmployeeTimeOffPolicy.exists?(etops.first.id) } }
          it { expect { subject }.to change { Employee::Balance.exists?(first_balance.id) } }
          it do
            expect { subject }
              .to change { Employee::Balance.where(balance_type: 'assignation').count }.by(-1)
          end

          it { expect { subject }.to_not change { second_balance.reload.manual_amount } }
          it { expect { subject }.to_not change { newest_balance.reload.manual_amount } }
          it { expect { subject }.to_not change { epp.reload.effective_at } }

          context 'it does not change policy credit addition to true while not policy start date' do
            let(:effective_at) { 1.year.since + 2.day }

            it { expect { subject }.to_not change { newest_balance.reload.balance_type } }
          end

          context 'and there are removals which should be destroyed' do
            before do
              employee.employee_balances.where(time_off_category: second_category).destroy_all
              etops.last.destroy!
              EmployeeTimeOffPolicy.all.map do |etop|
                ManageEmployeeBalanceAdditions.new(etop).call
              end
              Employee::Balance.order(:effective_at).map do |balance|
                UpdateEmployeeBalance.new(balance).call
              end
            end

            let!(:removals_to_destroy) do
              Employee::Balance
                .where('effective_at BETWEEN ? AND ?', event.effective_at, effective_at)
                .order(:effective_at)
                .map(&:balance_credit_removal).uniq.compact
            end
            let(:effective_at) { 2.months.since }

            it do
              subject
              removals_to_destroy.map do |removal|
                next unless removal.balance_credit_additions.blank?
                expect(Employee::Balance.exists?(removal.id)).to eq false
              end
            end

            it do
              expect { subject }
                .to change { Employee::Balance.where(balance_type: 'removal').count }.by(-2)
            end
          end

          context 'and hired date was one day after contract end and now not' do
            before do
              create(:employee_event,
                event_type: 'contract_end', employee: employee, effective_at: 1.year.ago)
              EmployeeTimeOffPolicy.all.map do |etop|
                ManageEmployeeBalanceAdditions.new(etop).call
              end
            end
            let!(:rehired) do
              create(:employee_event,
                event_type: 'hired', employee: employee, effective_at: 1.year.ago + 2.days)
            end
            let(:event_id) { rehired.id }
            let(:employee_attributes_params) do
              [{ attribute_name: 'occupation_rate', value: '0.5' }]
            end

            context 'and rehired event does not have etops and ewp assigned' do
              it { expect { subject }.to_not change { EmployeeTimeOffPolicy.count } }
              it { expect { subject }.to change { EmployeePresencePolicy.count } }
              it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }
              it do
                expect { subject }
                  .to_not change { Employee::Balance.where(balance_type: 'reset').count }
              end

              it { expect { subject }.to change { rehired.reload.effective_at } }
            end

            context 'and rehired event has ewps and epps assigned' do
              before do
                create(:employee_working_place,
                  employee: employee, effective_at: rehired.effective_at)
                create(:employee_time_off_policy, :with_employee_balance,
                  employee: employee, effective_at: rehired.effective_at,
                  time_off_policy:
                    create(:time_off_policy, :with_end_date, time_off_category: first_category)
                )
              end

              it { expect { subject }.to_not change { EmployeeTimeOffPolicy.with_reset.count } }
              it { expect { subject }.to_not change { EmployeeWorkingPlace.with_reset.count } }
              it { expect { subject }.to change { rehired.reload.effective_at } }

              it { expect { subject }.to_not change { EmployeePresencePolicy.with_reset.count } }
              it { expect { subject }.to_not change { EmployeeTimeOffPolicy.not_reset.count } }
              it do
                expect { subject }
                  .to_not change { Employee::Balance.where(balance_type: 'reset').count }
              end
            end
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
            end

            context 'and hired date moved to not etop start date' do
              let(:effective_at) { 1.year.since + 1.day }

              it { expect { subject }.to change { EmployeeTimeOffPolicy.count }.by(-1) }
              it { expect { subject }.to change { Employee::Balance.exists?(first_balance.id) } }
              it { expect { subject }.to change { Employee::Balance.count }.by(-19) }
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
          it { expect { subject }.to change { Employee::Balance.additions.count }.by(2) }
          it { expect { subject }.to change { Employee::Balance.removals.count }.by(2) }
          it { expect { subject }.to change { Employee::Balance.count}.by(6) }

          it { expect { subject }.to_not change { first_balance.reload.manual_amount } }
          it { expect { subject }.to_not change { second_balance.reload.manual_amount } }
          it { expect { subject }.to_not change { newest_balance.reload.manual_amount } }
          it { expect { subject }.to_not change { new_etop.reload.effective_at } }
          it { expect { subject }.to_not change { newest_balance.reload.effective_at } }
          it { expect { subject }.to_not change { epp.reload.effective_at } }

          it { expect { subject }.to_not change { EmployeeTimeOffPolicy.exists?(etops.first.id) } }
        end

        context 'when there is contract end at day before new effective' do
          let(:employee_attributes_params) { [{ attribute_name: 'occupation_rate', value: '0.5' }] }
          let!(:epp) do
            create(:employee_presence_policy, employee: employee, effective_at: event.effective_at)
          end
          let!(:contract_end) do
            create(:employee_event,
              event_type: 'contract_end', employee: employee, effective_at: 1.year.ago)
          end
          let!(:rehired) do
            create(:employee_event,
              event_type: 'hired', employee: employee, effective_at: 8.months.ago)
          end

          before do
            validity_date =
              RelatedPolicyPeriod.new(new_etop).validity_date_for_balance_at(new_etop.effective_at)

            EmployeeTimeOffPolicy.order(:effective_at).map do |etop|
              etop.policy_assignation_balance.update!(validity_date: validity_date)
              ManageEmployeeBalanceAdditions.new(etop).call
            end
            params[:effective_at] = contract_end.effective_at + 1.day
            params[:id] = rehired.id
          end

          context 'and there are no join tables assigned at rehired event effective_at' do
            it { expect { subject }.to_not change { EmployeeTimeOffPolicy.with_reset.count } }
            it { expect { subject }.to change { EmployeePresencePolicy.with_reset.count }.by(-1) }
            it { expect { subject }.to_not change { EmployeeWorkingPlace.with_reset.count } }
            it do
              expect { subject }
                .to_not change { Employee::Balance.where(balance_type: 'reset').count }
            end
            it do
              expect { subject }.to change { rehired.reload.effective_at }
                .to eq(contract_end.effective_at + 1.day)
            end
          end

          context 'and there are join tables assigned at rehired event effective_at' do
            let!(:rehired_etop) do
              create(:employee_time_off_policy, :with_employee_balance,
                employee: employee, effective_at: rehired.effective_at,
                time_off_policy:
                  create(:time_off_policy, :with_end_date, time_off_category: first_category))
            end
            let!(:rehired_epp) do
              create(:employee_presence_policy,
                employee: employee, effective_at: rehired.effective_at)
            end
            let!(:rehired_ewp) do
              create(:employee_working_place,
                employee: employee, effective_at: rehired.effective_at )
            end

            let(:balances_in_first_category) do
              Employee::Balance.in_category(first_category).order(:effective_at)
            end

            let(:balances_in_second_category) do
              Employee::Balance.in_category(second_category).order(:effective_at)
            end

            it { expect { subject }.to_not change { Employee::Balance.where(balance_type: 'assignation').count } }
            it do
              expect { subject }.to change { EmployeeTimeOffPolicy.with_reset.count }.from(2).to(1)
            end
            it do
              expect { subject }.to change { EmployeePresencePolicy.with_reset.count }.from(1).to(0)
            end
            it do
              expect { subject }.to change { EmployeeWorkingPlace.with_reset.count }.from(1).to(0)
            end
            it do
              expect { subject }
                .to_not change { Employee::Balance.where(balance_type: 'reset').count }
            end
            it do
              expect { subject }.to change { rehired.reload.effective_at }
                .to eq(contract_end.effective_at + 1.day)
            end

            it 'has valid effective at for join tables' do
              subject

              expect(EmployeeWorkingPlace.not_reset.order(:effective_at).pluck(:effective_at))
                .to match_array(
                  %w(2/1/2014 2/1/2015).map(&:to_date)
                )
              expect(EmployeePresencePolicy.not_reset.order(:effective_at).pluck(:effective_at))
                .to match_array(
                  %w(2/1/2014 2/1/2015).map(&:to_date)
                )

              expect(EmployeeTimeOffPolicy.not_reset.order(:effective_at).pluck(:effective_at))
                .to match_array(
                  %w(2/1/2014 2/1/2014 6/1/2014 2/1/2015).map(&:to_date)
                )
            end

            it 'has valid effective at for employee balance' do
              subject
              expect(balances_in_first_category.pluck(:effective_at).map(&:to_date)).to match_array(
                %w(
                  2/1/2014 6/1/2014 1/1/2015 1/1/2015 2/1/2015 2/1/2015 1/1/2016 1/1/2016
                  2/4/2016 1/1/2017 1/1/2017 2/4/2017 1/1/2018 1/1/2018 2/4/2018 2/4/2019
                ).map(&:to_date)
              )
              expect(balances_in_second_category.pluck(:effective_at).map(&:to_date)).to match_array(
                %w(2/1/2014 1/1/2015 1/1/2015 2/1/2015).map(&:to_date)
              )
            end

            it 'has valid types for balances' do
              subject

              expect(balances_in_first_category.pluck(:balance_type)).to match_array(
                %w(
                  assignation assignation end_of_period addition reset assignation end_of_period
                  addition removal end_of_period addition removal end_of_period addition
                  removal removal
                )
              )
              expect(balances_in_second_category.pluck(:balance_type)).to match_array(
                %w(assignation end_of_period addition reset)
              )
            end
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

      it { expect { subject }.to change { event.employee_attribute_versions.count }.by(3) }
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

      it { expect { subject }.to change { event.employee_attribute_versions.count }.by(3) }
      it 'has valid data' do
        subject
        expect(event.employee_attribute_versions.where(attribute_definition: child_definition)
          .first.data.value[:firstname]).to eq('Arya')
      end
    end
  end

  context 'contract_end' do
    let(:event_type) { 'contract_end' }
    let!(:categories) { create_list(:time_off_category, 2, account: employee.account) }
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
    let!(:etop_for_time_off) do
      create(:employee_time_off_policy, :with_employee_balance,
        employee: employee, effective_at: 1.year.ago - 2.days,
        time_off_policy: create(:time_off_policy, :with_end_date, time_off_category: categories.first))
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
    let!(:event) do
      create(:employee_event,
        employee: employee, event_type: 'contract_end', effective_at: Time.zone.today)
    end
    let(:employee_attributes_params) {{ }}
    let(:reset_balance_effective_at) { effective_at + 1.day + Employee::Balance::RESET_OFFSET }

    before do
      time_offs.map do |time_off|
        validity_date =
          RelatedPolicyPeriod
            .new(time_off.employee_balance.employee_time_off_policy)
            .validity_date_for_balance_at(time_off.end_time)
        UpdateEmployeeBalance.new(time_off.employee_balance, validity_date: validity_date).call
      end
      etops.map do |etop|
        validity_date = RelatedPolicyPeriod.new(etop).validity_date_for_balance_at(etop.effective_at)
        UpdateEmployeeBalance.new(
          etop.policy_assignation_balance, validity_date: validity_date
        ).call
        ManageEmployeeBalanceAdditions.new(etop).call
      end
    end

    context 'and hired date was one day after and now it is more' do
      before { params[:effective_at] = 10.months.ago }

      let!(:rehired) do
        create(:employee_event,
          event_type: 'hired', employee: employee, effective_at: event.effective_at + 1.day)
      end

      context 'and there was not join tables assigned at hired date' do
        it { expect { subject }.to_not change { EmployeeTimeOffPolicy.count } }
        it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }
        it { expect { subject }.to_not change { EmployeePresencePolicy.count } }
        it do
          expect { subject }.to_not change { Employee::Balance.where(balance_type: 'reset').count }
        end

        it { expect { subject }.to change { TimeOff.count }.by(-1) }
        it { expect { subject }.to change { event.reload.effective_at } }
        it do
          expect { subject }.to change { Employee::Balance.where.not(validity_date: nil)
            .pluck(:validity_date).uniq.map(&:to_date) }.to([10.months.ago.to_date + 1.day])
        end
        it do
          expect { subject }.to change { Employee::Balance.where(balance_type: 'removal').count }
        end
      end

      context 'and there were join tables assigned at hired date' do
        before do
          create(:employee_time_off_policy, :with_employee_balance,
            employee: employee, time_off_policy: policies.first, effective_at: rehired.effective_at)
        end
        let!(:rehired_balance) do
          employee
            .employee_balances.in_category(policies.first.time_off_category)
            .where("effective_at::date = ? AND balance_type = 'assignation'", rehired.effective_at)
            .first
        end

        it { expect { subject }.to_not change { EmployeeWorkingPlace.count } }
        it { expect { subject }.to_not change { EmployeePresencePolicy.count } }
        it { expect { subject }.to_not change { rehired_balance.reload.validity_date } }
        it { expect { subject }.to change { EmployeeTimeOffPolicy.with_reset.count }.by(1) }
        it { expect { subject }.to change { EmployeeTimeOffPolicy.count }.by(1) }
        it { expect { subject }.to change { TimeOff.count }.by(-1) }
        it do
          expect { subject }.to change { Employee::Balance.where(balance_type: 'removal').count }
        end
        it do
          expect { subject }
            .to change { Employee::Balance.where.not(validity_date: nil, id: rehired_balance.id)
            .pluck(:validity_date).uniq.map(&:to_date) }.to([10.months.ago.to_date + 1.day])
        end
      end
    end

    context 'and hired day now one day after' do
      before { params[:effective_at] = rehired.effective_at - 1.day }
      let!(:rehired) do
        create(:employee_event, event_type: 'hired', employee: employee, effective_at: 1.year.since)
      end

      context 'and there are no join tables assigned to the new etop' do
        it { expect { subject }.to_not change { EmployeeTimeOffPolicy.with_reset.count } }
        it { expect { subject }.to_not change { EmployeePresencePolicy.with_reset.count } }
        it { expect { subject }.to_not change { EmployeeWorkingPlace.with_reset.count } }
        it { expect { subject }.to change { event.reload.effective_at } }
        it do
          expect { subject }.to_not change { Employee::Balance.where(balance_type: 'reset').count }
        end
      end

      context 'and there are join tables assigned to the new etop' do
        let!(:rehired_etop) do
          create(:employee_time_off_policy, :with_employee_balance,
            effective_at: rehired.effective_at, employee: employee,
            time_off_policy: create(:time_off_policy, :with_end_date,
            time_off_category: categories.first))
        end
        let(:balances_in_first) do
          Employee::Balance.where(time_off_category: categories.first).order(:effective_at)
        end
        let!(:rehired_ewp) do
          create(:employee_working_place, employee: employee, effective_at: rehired.effective_at)
        end

        it { expect { subject }.to change { EmployeeTimeOffPolicy.with_reset.count }.from(2).to(1) }
        it { expect { subject }.to change { EmployeeWorkingPlace.with_reset.count }.from(1).to(0) }
        it { expect { subject }.to_not change { EmployeePresencePolicy.with_reset.count } }
        it { expect { subject }.to change { event.reload.effective_at } }
        it do
          expect { subject }.to_not change { Employee::Balance.where(balance_type: 'reset').count }
        end

        it 'has valid effective at for employee balance' do
          subject
          expect(balances_in_first.pluck(:effective_at).map(&:to_date)).to match_array(
            %w(
              30/12/2014 1/1/2015 1/1/2015 6/1/2015 2/4/2015 4/9/2015 1/1/2016 1/1/2016
              2/4/2016 1/1/2017 1/1/2017 1/1/2017
            ).map(&:to_date)
          )
        end

        it 'has valid types for balances' do
          subject
          expect(balances_in_first.pluck(:balance_type)).to match_array(
            %w(
              addition assignation assignation assignation end_of_period end_of_period
              end_of_period removal removal reset time_off time_off
            )
          )
        end
      end
    end

    context 'move to the future' do
      before do
        subject
        event.reload
        employee.reload
      end

      shared_examples 'Contract end in the future' do
        it { expect(event.effective_at).to eq effective_at }
        it { expect(employee.employee_time_off_policies.count).to eq(5) }
        it { expect(employee.employee_working_places.count).to eq(2) }
        it { expect(employee.employee_presence_policies.count).to eq(2) }
        it { expect(employee.time_offs.count).to eq (2) }
        it { expect(employee.employee_balances.where(balance_type: 'reset').count).to eq (2) }
        it do
          expect(time_offs.first.employee_balance.reload.validity_date.to_date)
            .to eq ('2016/4/2').to_date
        end
        it do
          expect(time_offs.last.employee_balance.reload.validity_date.to_date)
            .to eq ('2016/4/2').to_date
        end
        it do
          expect(employee.employee_balances.where(balance_type: 'reset')
            .pluck(:effective_at).uniq).to eq ([reset_balance_effective_at])
        end
      end

      context 'and contract end before policy start date' do
        let(:effective_at) { 1.year.since - 1.days }

        it { expect(employee.employee_balances.count).to eq (15) }
        it { expect(Employee::Balance.where(balance_type: 'assignation').count).to eq (3) }

        it_behaves_like 'Contract end in the future'
      end

      context 'when contract end in or after policy start date' do
        shared_examples 'Contract end in or after policy start date' do
          it { expect(Employee::Balance.additions.count).to eq (4) }
          it { expect(Employee::Balance.where(balance_type: 'assignation').count).to eq (3) }
          it { expect(employee.employee_balances.count).to eq (19) }
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
      before do
        subject
        event.reload
        employee.reload
      end

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
          it { expect(employee.employee_balances.count).to eq (7) }
          it { expect(employee.employee_balances.where(balance_type: 'reset').count).to eq (2) }
          it do
            expect(employee.employee_balances.where(balance_type: 'reset')
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
        before do
          employee_attributes_params.reject! { |attr| attr[:attribute_name].eql?('firstname') }
        end

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
