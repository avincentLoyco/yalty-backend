require 'rails_helper'

RSpec.describe JoinTableWithEffectiveTill, type: :service do
  include_context 'shared_context_account_helper'

  describe '#call' do
    let(:accounts) { create_list(:account, 2) }
    let(:employee_first) { create(:employee_with_working_place, account: accounts.first) }
    let(:employee_third) { create(:employee_with_working_place, account: accounts.second) }
    let(:account_id) { accounts.first.id }
    let(:from_date) { nil }
    let(:till_date) { nil }

    context 'when join table is EmployeeTimeOffPolicy' do
      subject { described_class.new(EmployeeTimeOffPolicy, account_id).call }

      context 'and there are employee time off policies' do
        let(:categories) { create_list(:time_off_category, 2, account: accounts.first) }
        let(:policy_first) { create(:time_off_policy, time_off_category: categories.first) }
        let(:policy_second) { create(:time_off_policy, time_off_category: categories.second) }
        let!(:etop_zero) do
          create(
            :employee_time_off_policy,
            employee: employee_first,
            time_off_policy: policy_second,
            effective_at: Time.now - 2.days
          )
        end
        let!(:etop_second) do
          create(
            :employee_time_off_policy,
            employee: employee_first,
            time_off_policy: policy_second,
            effective_at: Time.now + 2.days
          )
        end

        attributes = %w(id effective_at effective_till employee_id)
        it { subject.first {|etop| expect(etop.keys).to match_array(attributes) } }

        context 'and we pass the params from_date and till_date' do
          subject do
            described_class.new(
              EmployeeTimeOffPolicy, account_id, nil, nil, nil, from_date, till_date
            ).call
          end

          context 'and there are etop with effective_at smaller or equal till_date' do
            context 'and effective_till bigger or equal from_date' do
              let(:from_date) { Time.now + 2.days }
              let(:till_date) { Time.now + 5.days }

              before { subject }

              it { expect(subject.class).to eq Array }
              it { expect(subject.size).to eq 1 }

              it { expect(subject[0]['id']).to eq etop_second.id }
              it { subject.map { |etop| expect(etop['id']).not_to eq etop_zero.id } }
            end
          end

          context 'and there are no etops with effective_at smaller then till_date' do
            let(:till_date) { Time.now - 4.days }

            before { subject }

            it { expect(subject.class).to eq Array }
            it { expect(subject.size).to eq 0 }
          end

          context 'and there are etop with effective_till equal nil' do
            let(:from_date) { Time.now + 10.days }

            before { subject }

            it { expect(subject.class).to eq Array }
            it { expect(subject.size).to eq 1 }

            it { expect(subject[0]['id']).to eq etop_second.id }
            it { subject.map { |etop| expect(etop['id']).not_to eq etop_zero.id } }
          end
        end

        context 'and we pass the param resource_id' do
          subject do
            described_class.new(EmployeeTimeOffPolicy, account_id, resource_id).call
          end

          let(:resource_id) { policy_second.id }

          before { subject }

          it { expect(subject.class).to eq Array }
          it { expect(subject.size).to eq 2 }

          it { expect(subject[0]['id']).to eq etop_zero.id }
          it { expect(subject[1]['id']).to eq etop_second.id }
        end

        context 'and we pass the param employee_id' do
          subject { described_class.new(EmployeeTimeOffPolicy, account_id, nil, employee_id).call }
          let(:employee_id) { employee_first.id}

          before { subject }

          it { expect(subject.class).to eq Array }
          it { expect(subject.size).to eq 2 }

          it { subject.map { |etop| expect(etop['employee_id']).to eq employee_id } }
        end

        context 'and we pass the param join_table_id' do
          subject do
            described_class.new(EmployeeTimeOffPolicy, account_id, nil, nil, join_table_id).call
          end

          let(:join_table_id) { etop_second.id}

          before { subject }

          it { expect(subject.class).to eq Array }
          it { expect(subject.size).to eq 1 }

          it { subject.map { |etop| expect(etop['id']).to eq join_table_id } }
        end

        context 'and employees have multiple employee time off policies per category' do
          let(:employee_second) { create(:employee, account: accounts.first) }
          let!(:etop_first) do
            create(
              :employee_time_off_policy,
              employee: employee_first,
              time_off_policy: policy_first,
              effective_at: Time.now
            )
          end
          let!(:etop_second) do
            create(
              :employee_time_off_policy,
              employee: employee_second,
              time_off_policy: policy_second,
              effective_at: Time.now + 2.days
            )
          end
          let!(:etop_third) do
            create(
              :employee_time_off_policy,
              employee: employee_first,
              time_off_policy: policy_second,
              effective_at: Time.now + 4.days
            )
          end
          let!(:etop_fourth) do
            create(
              :employee_time_off_policy,
              employee: employee_first,
              time_off_policy: policy_first,
              effective_at: Time.now + 6.days
            )
          end
          let!(:etop_fifth) do
            create(
              :employee_time_off_policy,
              employee: employee_second,
              time_off_policy: policy_second,
              effective_at: Time.now + 8.days
            )
          end

          before { subject }

          it { expect(subject.class).to eq Array }
          it { expect(subject.size).to eq 6 }

          it { expect(subject[0]['effective_till']).to eq (etop_third.effective_at - 1.days).to_date.to_s }
          it { expect(subject[1]['effective_till']).to eq (etop_fourth.effective_at - 1.days).to_date.to_s }
          it { expect(subject[2]['effective_till']).to eq (etop_fifth.effective_at - 1.days).to_date.to_s }
          it { expect(subject[3]['effective_till']).to eq nil }
          it { expect(subject[4]['effective_till']).to eq nil }
          it { expect(subject[5]['effective_till']).to eq nil }
        end

        context 'and there are employee time off policies that are before current in the category' do
          let!(:etop_previous) do
            create(
              :employee_time_off_policy,
              employee: employee_first,
              time_off_policy: policy_second,
              effective_at: Time.now - 4.days
            )
          end

          before { subject }

          it { expect(subject.class).to eq Array }
          it { expect(subject.size).to eq 2 }

          it { expect(subject[0]['id']).to eq etop_zero.id }
          it { expect(subject[1]['id']).to eq etop_second.id }
          it { subject.map { |etop| expect(etop['id']).not_to eq etop_previous.id } }
        end

        context 'and there are employees with current employee time off policies but in other accounts' do
          let(:category_third) { create(:time_off_category, account: accounts.second) }
          let(:policy_third) { create(:time_off_policy, time_off_category: category_third) }
          let!(:etop_from_account_second) do
            create(
              :employee_time_off_policy,
              employee: employee_third,
              time_off_policy: policy_third,
              effective_at: Time.now
            )
          end

          before { subject }

          it { expect(subject.class).to eq Array }
          it { expect(subject.size).to eq 2 }

          it { expect(subject[0]['id']).to eq etop_zero.id }
          it { expect(subject[1]['id']).to eq etop_second.id }
          it { subject.map { |etop| expect(etop['id']).not_to eq etop_from_account_second.id } }
        end
      end

      context 'and employee has no policy in any category' do
        let(:account_id) { create(:account).id }

        before { subject }

        it { expect(subject.class).to eq Array }
        it { expect(subject).to eq [] }
      end
    end

    context 'when join table is EmployeePresencePolicy' do
      subject { described_class.new(EmployeePresencePolicy, account_id).call }

      context 'and there are employee presence policies' do
        let(:presence_policy) do
          create(:presence_policy, :with_presence_day, account: accounts.first)
        end
        let!(:epp_zero) do
          create(
            :employee_presence_policy,
            employee: employee_first,
            effective_at: Time.now - 2.days,
            presence_policy: presence_policy
          )
        end
        let!(:epp_second) do
          create(
            :employee_presence_policy,
            employee: employee_first,
            effective_at: Time.now + 2.days,
            presence_policy: presence_policy
          )
        end

        attributes = %w(id effective_at effective_till employee_id order_of_start_day)
        it { subject.first {|epp| expect(epp.keys).to match_array(attributes) } }

        context 'and we pass the params from_date and till_date' do
          subject do
            described_class.new(
              EmployeePresencePolicy, account_id, nil, nil, nil, from_date, till_date
            ).call
          end

          context 'and there are policy with effective_at smaller or equal till_date' do
            context ' and effective_till bigger or equal from_date' do
              let(:from_date) { Time.now + 2.days }
              let(:till_date) { Time.now + 5.days }

              before { subject }

              it { expect(subject.class).to eq Array }
              it { expect(subject.size).to eq 1 }

              it { expect(subject[0]['id']).to eq epp_second.id }
              it { subject.map { |epp| expect(epp['id']).not_to eq epp_zero.id } }
            end
          end

          context 'and there are no policies with effective_at smaller then till_date' do
            let(:till_date) { Time.now - 4.days }

            before { subject }

            it { expect(subject.class).to eq Array }
            it { expect(subject.size).to eq 0 }
          end

          context 'and there are policy with effective_till equal nil' do
            let(:from_date) { Time.now + 10.days }

            before { subject }

            it { expect(subject.class).to eq Array }
            it { expect(subject.size).to eq 1 }

            it { expect(subject[0]['id']).to eq epp_second.id }
            it { subject.map { |epp| expect(epp['id']).not_to eq epp_zero.id } }
          end
        end

        context 'and we pass the param resource_id' do
          subject { described_class.new(EmployeePresencePolicy, account_id, resource_id).call }
          let(:resource_id) { epp_zero.presence_policy_id }

          before { subject }

          it { expect(subject.class).to eq Array }
          it { expect(subject.size).to eq 2 }

          it { expect(subject[0]['id']).to eq epp_zero.id }
          it { expect(subject[1]['id']).to eq epp_second.id }
        end

        context 'and we pass the param employee_id' do
          subject { described_class.new(EmployeePresencePolicy, account_id, nil, employee_id).call }
          let(:employee_id) { employee_first.id}

          before { subject }

          it { expect(subject.class).to eq Array }
          it { expect(subject.size).to eq 2 }

          it { subject.map { |epp| expect(epp['employee_id']).to eq employee_id } }
        end

        context 'and we pass the param join_table_id' do
          subject do
            described_class.new(EmployeePresencePolicy, account_id, nil, nil, join_table_id).call
          end

          let(:join_table_id) { epp_second.id}

          before { subject }

          it { expect(subject.class).to eq Array }
          it { expect(subject.size).to eq 1 }

          it { subject.map { |epp| expect(epp['id']).to eq join_table_id } }
        end

        context 'and employees have multiple employee presence policies' do
          let(:employee_second) { create(:employee, account: accounts.first) }
          let!(:epp_first) do
            create(:employee_presence_policy,
              employee: employee_first,
              effective_at: Time.now
            )
          end
          let!(:epp_second) do
            create(:employee_presence_policy,
              employee: employee_second,
              effective_at: Time.now + 2.days
            )
          end
          let!(:epp_third) do
            create(:employee_presence_policy,
              employee: employee_second,
              effective_at: Time.now + 4.days
            )
          end

          before { subject }

          it { expect(subject.class).to eq Array }
          it { expect(subject.size).to eq 3 }

          it { expect(subject[0]['effective_till']).to eq nil }
          it { expect(subject[1]['effective_till']).to eq (epp_third.effective_at - 1.days).to_date.to_s }
          it { expect(subject[2]['effective_till']).to eq nil }
        end

        context 'and there are employee presence policies that are previous to the current' do
          let!(:epp_previous) do
            create(:employee_presence_policy,
              employee: employee_first,
              effective_at: Time.now - 4.days
            )
          end

          before { subject }

          it { expect(subject.class).to eq Array }
          it { expect(subject.size).to eq 2 }

          it { expect(subject[0]['id']).to eq epp_zero.id }
          it { expect(subject[1]['id']).to eq epp_second.id }
          it { subject.map { |epp| expect(epp['id']).not_to eq epp_previous.id } }
        end

        context 'and there are employees with current or future employee presence policies in other accounts' do
          let!(:epp_from_account_second) do
            create(:employee_presence_policy,
              employee: employee_third,
              effective_at: Time.now
            )
          end

          before { subject }

          it { expect(subject.class).to eq Array }
          it { expect(subject.size).to eq 2 }

          it { expect(subject[0]['id']).to eq epp_zero.id }
          it { expect(subject[1]['id']).to eq epp_second.id }
          it { subject.map { |epp| expect(epp['id']).not_to eq epp_from_account_second.id } }
        end

      end

      context 'and employee has no presence policy' do
        let(:account_id) { create(:account).id }

        before { subject }

        it { expect(subject.class).to eq Array }
        it { expect(subject).to eq [] }
      end
    end

    context 'when join table is EmployeeWorkingPlace' do
      subject { described_class.new(EmployeeWorkingPlace, account_id).call }

      context 'and there are employee working places' do
        let(:working_place_first)   { employee_first.employee_working_places.first.working_place }
        let(:working_place_second)  { employee_third.employee_working_places.first.working_place }
        let!(:ewp_first) do
          employee_first.employee_working_places.first.tap do |ewp|
            employee_first.first_employee_event.update!(effective_at: Time.now - 2.days)
            ewp.update!(effective_at: Time.now - 2.days)
          end
        end
        let!(:ewp_second) do
          create(:employee_working_place,
            employee: employee_first,
            working_place: working_place_second,
            effective_at: Time.now + 2.days
          )
        end

        attributes = %w(id effective_at effective_till employee_id)
        it { subject.first {|etop| expect(etop.keys).to match_array(attributes) } }

        context 'and we pass the params from_date and till_date' do
          subject do
            described_class.new(
              EmployeeWorkingPlace, account_id, nil, nil, nil, from_date, till_date
            ).call
          end

          context 'and there are working place with effective_at smaller or equal till_date' do
            context 'and effective_till bigger or equal from_date' do
              let(:from_date) { Time.now + 2.days }
              let(:till_date) { Time.now + 5.days }

              before { subject }

              it { expect(subject.class).to eq Array }
              it { expect(subject.size).to eq 1 }

              it { expect(subject[0]['id']).to eq ewp_second.id }
              it { subject.map { |ewp| expect(ewp['id']).not_to eq ewp_first.id } }
            end
          end

          context 'and there are no working places with effective_at smaller then till_date' do
            let(:till_date) { Time.now - 4.days }

            before { subject }

            it { expect(subject.class).to eq Array }
            it { expect(subject.size).to eq 0 }
          end

          context 'and there are working place with effective_till equal nil' do
            let(:from_date) { Time.now + 10.days }

            before { subject }

            it { expect(subject.class).to eq Array }
            it { expect(subject.size).to eq 1 }

            it { expect(subject[0]['id']).to eq ewp_second.id }
            it { subject.map { |ewp| expect(ewp['id']).not_to eq ewp_first.id } }
          end
        end

        context 'and we pass the param resource_id' do
          subject { described_class.new(EmployeeWorkingPlace, account_id, resource_id).call }

          let(:resource_id) { working_place_first.id }

          before { subject }

          it { expect(subject.class).to eq Array }
          it { expect(subject.size).to eq 1 }

          it { expect(subject[0]['id']).to eq ewp_first.id }
        end

        context 'and we pass the param employee_id' do
          subject { described_class.new(EmployeeWorkingPlace, account_id, nil, employee_id).call }

          let(:employee_id) { employee_first.id}

          before { subject }

          it { expect(subject.class).to eq Array }
          it { expect(subject.size).to eq 2 }

          it { subject.map { |ewp| expect(ewp['employee_id']).to eq employee_id } }
        end

        context 'and we pass the param join_table_id' do
          subject do
            described_class.new(EmployeeWorkingPlace, account_id, nil, nil, join_table_id).call
          end

          let(:join_table_id) { ewp_first.id}

          before { subject }

          it { expect(subject.class).to eq Array }
          it { expect(subject.size).to eq 1 }

          it { subject.map { |ewp| expect(ewp['id']).to eq join_table_id } }
        end

        context 'and employees have multiple employee working places on the same account' do
          let(:employee_second) { create(:employee_with_working_place, account: accounts.first) }
          let!(:ewp_from_employee_second) do
            employee_second.employee_working_places.first.tap do |ewp|
              employee_second.first_employee_event.update!(effective_at: Time.now)
              ewp.update(effective_at: Time.now)
            end
          end

          before { subject }

          it { expect(subject.class).to eq Array }
          it { expect(subject.size).to eq 3 }

          it { expect(subject[0]['effective_till']).to eq (ewp_second.effective_at - 1.days).to_date.to_s }
          it { expect(subject[1]['effective_till']).to eq nil }
          it { expect(subject[2]['effective_till']).to eq nil }
        end

        context 'and there are employee working places that are previous to the current' do
          let!(:ewp_in_the_middle) do
            create(:employee_working_place,
              employee: employee_first,
              working_place: working_place_first,
              effective_at: Time.now
            )
          end

          before { subject }

          it { expect(subject.class).to eq Array }
          it { expect(subject.size).to eq 2 }

          it { expect(subject[0]['id']).to eq ewp_in_the_middle.id }
          it { expect(subject[1]['id']).to eq ewp_second.id }
          it { subject.map { |ewp| expect(ewp['id']).not_to eq ewp_first.id } }
        end

        context 'and there are employees with current employee working places but from other accounts' do
          let!(:ewp_from_account_second) do
            employee_third.employee_working_places.first.tap do |ewp|
              ewp.update(effective_at: Time.now)
            end
          end

          before { subject }

          it { expect(subject.class).to eq Array }
          it { expect(subject.size).to eq 2 }

          it { expect(subject[0]['id']).to eq ewp_first.id }
          it { expect(subject[1]['id']).to eq ewp_second.id }
          it { subject.map { |ewp| expect(ewp['id']).not_to eq ewp_from_account_second.id } }
        end
      end

      context 'and account has no working places' do
        let(:account_id) { create(:account).id }

        before { subject }

        it { expect(subject.class).to eq Array }
        it { expect(subject).to eq [] }
      end
    end
  end
end
