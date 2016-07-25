require 'rails_helper'

RSpec.describe CreateJoinTableService, type: :service do
  include_context 'shared_context_account_helper'
  before { Account.current = create(:account) }

  describe '#call' do
    let(:employee) { create(:employee, account: Account.current) }
    let(:params) do
      {
        effective_at: '1/4/2015',
        id: employee.id
      }.merge(resource_params)
    end

    subject { described_class.new(join_table_class, resource_class, params).call }

    shared_examples 'Join Table update' do
      it { expect { subject }.to_not raise_error }

      it { expect { subject }.to change { join_table_class.exists?(existing_join_table.id) } }

      it { expect(subject.effective_at).to eq params[:effective_at].to_date }
    end

    shared_examples 'Join Table update with the same resource before' do
      it { expect { subject }.to_not raise_error }

      it { expect { subject }.to change { join_table_class.exists?(existing_join_table.id) } }
      it { expect { subject }.to change { join_table_class.count }.by(-1) }

      it { expect(subject.effective_at).to eq same_resource_before.effective_at }
      it { expect(subject.id).to eq same_resource_before.id }
    end

    shared_examples 'Join Table update with the same resource after' do
      it { expect { subject }.to_not raise_error }

      it { expect { subject }.to change { join_table_class.count }.by(-1) }
      it { expect { subject }.to change { join_table_class.exists?(existing_join_table.id) } }
      it { expect { subject }.to change { join_table_class.exists?(same_resource_after.id) } }

      it { expect(subject.effective_at).to eq params[:effective_at].to_date }
    end

    shared_examples 'Join Table update with the same resource after and before' do
      it { expect { subject }.to_not raise_error }

      it { expect { subject }.to change { join_table_class.count }.by(-2) }
      it { expect { subject }.to change { join_table_class.exists?(existing_join_table.id) } }
      it { expect { subject }.to change { join_table_class.exists?(same_resources.last.id) } }

      it { expect(subject.effective_at).to eq same_resources.first.effective_at }
      it { expect(subject.id).to eq same_resources.first.id }
    end

    shared_examples 'Duplicated Join Table' do
      it 'should raise error with proper message' do
         expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError)
      end
    end

    shared_examples 'Invalid date format' do
      let(:params) do
        {
          effective_at: 'abc',
          id: employee.id
        }.merge(resource_params)
      end

      it 'should raise error with proper message' do
         expect { subject }.to raise_error(API::V1::Exceptions::InvalidParamTypeError)
      end
    end

    context 'for EmployeeWorkingPlace' do
      before do
        employee.employee_working_places.first.update!(
          effective_at: employee.events.first.effective_at
        )
      end

      let(:resource_class) { WorkingPlace }
      let(:join_table_class) { EmployeeWorkingPlace }
      let(:resource) { create(:working_place, account: Account.current) }
      let(:resource_params) { { working_place_id: resource.id } }
      let!(:existing_join_table) do
        create(:employee_working_place, effective_at: '1/4/2015', employee: employee)
      end

      it_behaves_like 'Join Table update'
      it_behaves_like 'Invalid date format'

      context 'when there is Join Table with the same resource and date' do
        let(:resource_params) { { working_place_id: existing_join_table.working_place_id } }

        it_behaves_like 'Duplicated Join Table'
      end

      context 'when there is JoinTable with the same reosurce assigned before' do
        let!(:same_resource_before) do
          create(:employee_working_place,
            effective_at: '1/3/2015', employee: employee, working_place: resource)
        end

        it_behaves_like 'Join Table update with the same resource before'
      end

      context 'when there is JoinTable with the same reosurce assigned after' do
        let!(:same_resource_after) do
          create(:employee_working_place,
            effective_at: '1/5/2015', employee: employee, working_place: resource)
        end

        it_behaves_like 'Join Table update with the same resource after'
      end

      context 'when there is JoinTable with the same reosurce assigned before and after' do
        let!(:same_resources) do
          ['1/3/2015', '1/5/2015'].map do |date|
            create(:employee_working_place,
              employee: employee, working_place: resource, effective_at: date)
          end
        end

        it_behaves_like 'Join Table update with the same resource after and before'
      end
    end

    context 'for EmployeeTimeOffPolicy' do
      let(:category) { create(:time_off_category, account: Account.current) }
      let(:resource) { create(:time_off_policy, time_off_category: category) }
      let(:resource_params) { { time_off_policy_id: resource.id } }
      let(:resource_class) { TimeOffPolicy }
      let(:join_table_class) { EmployeeTimeOffPolicy }
      let!(:existing_join_table) do
        create(:employee_time_off_policy, effective_at: '1/4/2015', employee: employee)
      end

      it_behaves_like 'Join Table update'
      it_behaves_like 'Invalid date format'

      context 'when there is Join Table with the same resource and date' do
        let(:resource_params) { { time_off_policy_id: existing_join_table.time_off_policy_id } }

        it_behaves_like 'Duplicated Join Table'
      end

      context 'when there is JoinTable with the same reosurce assigned before' do
        let!(:same_resource_before) do
          create(:employee_time_off_policy,
            effective_at: '1/3/2015', employee: employee, time_off_policy: resource)
        end

        it_behaves_like 'Join Table update with the same resource before'
      end

      context 'when there is JoinTable with the same reosurce assigned after' do
        let!(:same_resource_after) do
          create(:employee_time_off_policy,
            effective_at: '1/5/2015', employee: employee, time_off_policy: resource)
        end

        it_behaves_like 'Join Table update with the same resource after'
      end

      context 'when there is JoinTable with the same reosurce assigned before and after' do
        let!(:same_resources) do
          ['1/3/2015', '1/5/2015'].map do |date|
            create(:employee_time_off_policy,
              employee: employee, time_off_policy: resource, effective_at: date)
          end
        end

        it_behaves_like 'Join Table update with the same resource after and before'
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

      it_behaves_like 'Join Table update'
      it_behaves_like 'Invalid date format'

      context 'when there is Join Table with the same resource and date' do
        let(:resource_params) { { presence_policy_id: existing_join_table.presence_policy_id } }

        it_behaves_like 'Duplicated Join Table'
      end

      context 'when there is JoinTable with the same reosurce assigned before' do
        let!(:same_resource_before) do
          create(:employee_presence_policy,
            effective_at: '1/3/2015', employee: employee, presence_policy: resource)
        end

        it_behaves_like 'Join Table update with the same resource before'
      end

      context 'when there is JoinTable with the same reosurce assigned after' do
        let!(:same_resource_after) do
          create(:employee_presence_policy,
            effective_at: '1/5/2015', employee: employee, presence_policy: resource)
        end

        it_behaves_like 'Join Table update with the same resource after'
      end

      context 'when there is JoinTable with the same reosurce assigned before and after' do
        let!(:same_resources) do
          ['1/3/2015', '1/5/2015'].map do |date|
            create(:employee_presence_policy,
              employee: employee, presence_policy: resource, effective_at: date)
          end
        end

        it_behaves_like 'Join Table update with the same resource after and before'
      end
    end
  end
end
