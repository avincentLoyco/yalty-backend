require 'rails_helper'

RSpec.describe FindAndUpdateEmployeeBalancesForJoinTables do
  include ActiveJob::TestHelper
  include_context 'shared_context_account_helper'
  include_context 'shared_context_timecop_helper'

  let(:account) { create(:account) }
  let(:employee) { create(:employee, account: account) }
  let(:categories) { create_list(:time_off_category, 2, account: account) }
  let(:policies) { categories.map { |cat| create(:time_off_policy, time_off_category: cat) } }
  let!(:employee_policies) do
    policies.map do |policy|
      create(:employee_time_off_policy,
        employee: employee, time_off_policy: policy, effective_at: employee.hired_date)
    end
  end
  let!(:time_offs) do
    dates_with_categories =
      [[3.months.since, 4.months.since, categories.first],
       [5.months.since, 6.months.since, categories.last]]
    dates_with_categories.map do |starts, ends, category|
      create(:time_off,
        end_time: ends, start_time: ends, employee: employee, time_off_category: category)
    end
  end
  let(:balances) { TimeOff.all.map(&:employee_balance).sort_by { |b| b[:effective_at] } }

  subject { described_class.new(join_table, employee, new_date).call }

  shared_examples 'All balances update' do
    it { expect { subject }.to change { balances.first.reload.being_processed }.to true }
    it { expect { subject }.to change { balances.last.reload.being_processed }.to true }
    it { expect { subject }.to change { enqueued_jobs.size }.by(2) }
  end

  shared_examples 'No balances update' do
    it { expect { subject }.to_not change { balances.first.reload.being_processed } }
    it { expect { subject }.to_not change { balances.last.reload.being_processed } }
    it { expect { subject }.to_not change { enqueued_jobs.size } }
  end

  describe 'For EmployeeWorkingPlace' do
    let!(:employee_working_place) do
      create(:employee_working_place, employee: employee, effective_at: Time.now)
    end
    let!(:join_table) { employee_working_place }
    let(:new_date) { Time.now }
    let(:existing_resource) { nil }
    let(:previous_date) { nil }
    let(:holiday_policy) { create(:holiday_policy, account: account) }

    context 'for destroy' do
      context 'when there is no previous join table' do
        context 'and removed join table does not have holiday_policy' do
          it_behaves_like 'No balances update'
        end

        context 'and removed join table has holiday policy' do
          before { join_table.working_place.update!(holiday_policy: holiday_policy) }

          it_behaves_like 'All balances update'
        end
      end

      context 'when there is previous join table' do
        let(:first_employee_working_place) do
          create(:employee_working_place, employee: employee, effective_at: 4.years.ago)
        end

        context 'when previous and current join table have the same holiday policy' do
          before { WorkingPlace.update_all(holiday_policy_id: holiday_policy.id) }

          it_behaves_like 'No balances update'
        end

        context 'when previous and current join table have different holiday policies' do
          before { join_table.working_place.update!(holiday_policy: holiday_policy) }

          it_behaves_like 'All balances update'
        end

        context 'when current and previous join table do not have holiday policy' do
          it_behaves_like 'No balances update'
        end
      end
    end

    context 'for create' do
      let!(:first_employee_working_place) do
        create(:employee_working_place, employee: employee, effective_at: 4.years.ago)
      end

      context 'when there is reassignation join table' do
        subject { described_class.new(join_table, employee, new_date, nil, existing_resource).call }

        before { employee_working_place.update!(effective_at: new_date) }
        let(:new_date) { 3.years.ago }
        let(:existing_resource) { reassignation_join_table.working_place }
        let!(:reassignation_join_table) do
          create(:employee_working_place, employee: employee, effective_at: 3.years.ago)
        end

        context 'and it has different holiday policy' do
          before do
            reassignation_join_table.working_place.update!(
              holiday_policy: create(:holiday_policy, account: account)
            )
          end

          it_behaves_like 'All balances update'
        end

        context 'and it does not have holiday policy assigned' do
          context 'and new join table does not have' do
            it_behaves_like 'No balances update'
          end

          context 'and new join table has' do
            before { employee_working_place.working_place.update!(holiday_policy: holiday_policy) }

            it_behaves_like 'All balances update'
          end
        end

        context 'and it has the same holiday policy assigned' do
          before do
            join_table.working_place.update!(holiday_policy: holiday_policy)
            reassignation_join_table.working_place.update!(holiday_policy: holiday_policy)
          end

          it_behaves_like 'No balances update'
        end
      end

      context 'when there is no reassignation join table' do
        context 'and there is no previous join table' do
          before { first_employee_working_place.destroy! }

          context 'and new join table does not have holiday policy' do
            it_behaves_like 'No balances update'
          end

          context 'and new join table has holiday policy' do
            before { join_table.working_place.update!(holiday_policy: holiday_policy) }

            it_behaves_like 'All balances update'
          end
        end

        context 'and there is previous join table' do
          context 'and it has different holiday policy' do
            before do
              join_table.working_place.update!(holiday_policy: holiday_policy)
              first_employee_working_place.working_place.update!(
                holiday_policy: create(:holiday_policy, account: account)
              )
            end

            it_behaves_like 'All balances update'
          end

          context 'and it has the same holiday policy' do
            before do
              WorkingPlace.update_all(holiday_policy_id: holiday_policy.id)
              join_table.working_place.reload
            end

            it_behaves_like 'No balances update'
          end
        end
      end
    end

    context 'for update' do
      let!(:older_time_offs) do
        dates_with_categories =
          [[3.months.ago, 4.months.ago, categories.first],
           [5.months.ago, 6.months.ago, categories.last]]
        dates_with_categories.map do |starts, ends, category|
          create(:time_off,
            end_time: ends, start_time: ends, employee: employee, time_off_category: category)
        end
      end
      let!(:employee_working_places) do
        [5.months.since, 7.months.ago, 5.months.ago].map do |date|
          create(:employee_working_place, employee: employee, effective_at: date)
        end
      end

      shared_examples 'All balances for previous update' do
        it { expect { subject }.to_not change { balances.first.reload.being_processed } }
        it { expect { subject }.to_not change { balances.second.reload.being_processed } }

        it { expect { subject }.to change { balances.third.reload.being_processed } }
        it { expect { subject }.to change { balances.last.reload.being_processed } }

        it { expect { subject }.to change { enqueued_jobs.size }.by(2) }
      end

      shared_examples 'All balances update' do
        it { expect { subject }.to change { balances.first.reload.being_processed } }
        it { expect { subject }.to change { balances.second.reload.being_processed } }
        it { expect { subject }.to change { balances.third.reload.being_processed } }
        it { expect { subject }.to change { balances.last.reload.being_processed } }

        it { expect { subject }.to change { enqueued_jobs.size }.by(2) }
      end

      shared_examples 'No balances update' do
        it { expect { subject }.to_not change { balances.first.reload.being_processed } }
        it { expect { subject }.to_not change { balances.second.reload.being_processed } }
        it { expect { subject }.to_not change { balances.third.reload.being_processed } }
        it { expect { subject }.to_not change { balances.last.reload.being_processed } }

        it { expect { subject }.to_not change { enqueued_jobs.size } }
      end

      shared_examples 'Only last balance update' do
        it { expect { subject }.to_not change { balances.first.reload.being_processed } }
        it { expect { subject }.to_not change { balances.second.reload.being_processed } }
        it { expect { subject }.to_not change { balances.third.reload.being_processed } }

        it { expect { subject }.to change { balances.last.reload.being_processed } }

        it { expect { subject }.to change { enqueued_jobs.size }.by(1) }
      end

      shared_examples 'All except first update' do
        it { expect { subject }.to_not change { balances.first.reload.being_processed } }

        it { expect { subject }.to change { balances.second.reload.being_processed } }
        it { expect { subject }.to change { balances.third.reload.being_processed } }
        it { expect { subject }.to change { balances.last.reload.being_processed } }

        it { expect { subject }.to change { enqueued_jobs.size }.by(2) }
      end

      context 'when there is reassignation join table' do
        subject do
          described_class.new(join_table, employee, new_date, previous_date, existing_resource).call
        end

        context 'when new effective_at is in the past' do
          let(:new_date) { 7.months.ago }
          let(:previous_date) { Time.now }
          let(:existing_resource) { employee_working_places.second.working_place }

          context 'and new holiday policy is the same' do
            context 'and it is different in the previous place' do
              before do
                employee_working_places.second.working_place.update!(holiday_policy: holiday_policy)
                join_table.working_place.update!(holiday_policy: holiday_policy)
              end

              it_behaves_like 'All balances for previous update'
            end

            context 'and it is the same in the previous place' do
              it_behaves_like 'No balances update'
            end
          end

          context 'and new holiday_policy is different' do
            before do
              employee_working_places.second.working_place.update!(holiday_policy: holiday_policy)
            end

            context 'and it is different in the previus place' do
              before do
                employee_working_places.last.working_place.update!(holiday_policy: holiday_policy)
              end

              it_behaves_like 'All balances update'
            end

            context 'and it is the same in the previous place' do
              it_behaves_like 'All balances update'
            end
          end
        end

        context 'when new effective at is in the future' do
          let(:new_date) { 5.months.since }
          let(:previous_date) { 5.months.ago }
          let(:existing_resource) { employee_working_places.first.working_place }
          let(:join_table) { employee_working_places.last }

          context 'and holiday policy is the same' do
            context 'and it is different in the previous place' do
              before do
                employee_working_places.second.working_place.update!(holiday_policy: holiday_policy)
              end

              it_behaves_like 'All except first update'
            end

            context'and it is the same at previous place' do
              it_behaves_like 'No balances update'
            end
          end

          context 'and holiday_policy is different' do
            before do
              employee_working_places.last.working_place.update!(holiday_policy: holiday_policy)
            end

            context 'and it is different in the previous place' do
              it_behaves_like 'All except first update'
            end

            context'and it is the same at previous place' do
              before do
                employee_working_places.second.working_place.update!(holiday_policy: holiday_policy)
              end

              it_behaves_like 'Only last balance update'
            end
          end
        end
      end

      context 'when there is no reassignation join table' do
        subject { described_class.new(join_table, employee, new_date, previous_date).call }

        context 'when new effective at is in the past' do
          let(:new_date) { 5.months.ago - 5.days }
          let(:previous_date) { Time.now }

          context 'and new holiday policy is the same' do
            context 'and it is different in the previous place' do
              before do
                employee_working_places.last.working_place.update!(holiday_policy: holiday_policy)
              end

              it_behaves_like 'All balances for previous update'
            end

            context 'and it is the same in the previous place' do
              it_behaves_like 'No balances update'
            end
          end

          context 'and new holiday policy is the different' do
            before do
              employee_working_places.second.working_place.update!(holiday_policy: holiday_policy)
            end

            context 'and it is different in the previous place' do
              before do
                employee_working_places.last.working_place.update!(holiday_policy: holiday_policy)
              end

              it_behaves_like 'All except first update'
            end

            context 'and it is the same in the previous place' do
              it_behaves_like 'All except first update'
            end
          end
        end

        context 'when new effective at is in the future' do
          let(:new_date) { 5.days.since }
          let(:previous_date) { 5.months.ago }
          let(:join_table) { employee_working_places.last }

          context 'and new holiday policy is the same' do
            context 'and it is different in the previous place' do
              before do
                employee_working_places.second.working_place.update!(holiday_policy: holiday_policy)
              end

              it_behaves_like 'All except first update'
            end

            context 'and it is the same in the previous place' do
              it_behaves_like 'No balances update'
            end
          end

          context 'and new holiday policy is the different' do
            before do
              employee_working_place.working_place.update!(holiday_policy: holiday_policy)
            end

            context 'and it is different in the previous place' do
              before do
                employee_working_places.second.working_place.update!(holiday_policy: holiday_policy)
              end

              it_behaves_like 'All except first update'
            end

            context 'and it is the same in the previous place' do
              it_behaves_like 'All balances for previous update'
            end
          end
        end
      end
    end
  end

  describe 'For EmployeePresencePolicy' do
    let!(:employee_presence_policy) do
      [Time.now, 5.months.since, 7.months.since].map do |date|
        create(:employee_presence_policy, employee: employee, effective_at: date)
      end
    end

    subject do
      described_class.new(join_table, employee, new_date, previous_date, existing_resource).call
    end

    context 'for create' do
      context 'when there was assignation join table' do

      end

      context 'when there was not assignation join table' do

      end
    end

    context 'for update' do


      context 'when there was assignation join table' do

      end

      context 'when there was not assignation join table' do

      end
    end

    context 'for destroy' do

    end
  end
end
