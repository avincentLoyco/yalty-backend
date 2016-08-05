require 'rails_helper'

RSpec.describe FindJoinTablesToDelete, type: :service do
  include_context 'shared_context_account_helper'

  subject do
    described_class.new(
      join_tables, new_effective_at, resource, resource_class, join_table_resource
    ).call
  end

  let(:account) { create(:account) }
  let(:new_effective_at) { Time.now - 2.years }
  let(:join_table_resource) { nil }
  let(:employee) { create(:employee, account: account) }

  shared_examples 'No employee join tables' do
    it { expect(subject).to eq [] }
  end

  shared_examples 'The same resource after effective at in create' do
    it { expect(subject).to include related_resource }
  end

  shared_examples 'The same resource before effective at in create' do
    it { expect(subject).to eq [] }
  end

  shared_examples 'The same resource after and before effective at in create' do
    it { expect(subject).to include newest_resource }
    it { expect(subject).to_not include related_resource }
  end

  shared_examples 'The same resource after previous effective_at' do
    it { expect(subject).to include new_resources.last }
    it { expect(subject).to_not include new_resources.first }
    it { expect(subject).to_not include new_resources.second }
  end

  shared_examples 'The same resource is after and before new effective_at' do
    it { expect(subject).to include new_resources.last }
    it { expect(subject).to include same_resource_tables.last }
    it { expect(subject).to_not include new_resources.first }
  end

  shared_examples 'The same resource is after and before new effective_at with reasign' do
    it { expect(subject).to include new_resources.last }
    it { expect(subject).to include same_resource_tables.last }
    it { expect(subject).to include new_resources.first }
  end

  context 'For EmployeeWorkingPlaces' do
    let(:resource_class) { 'working_place_id' }
    let(:resource) { create(:working_place, account: account) }
    let(:join_tables) { employee.employee_working_places }

    context 'when there are EmployeeWorkingPlaces with the same resource' do
      it_behaves_like 'No employee join tables'
    end

    context 'when EmployeeWorkingPlace is created' do
      let!(:related_resource) do
        create(:employee_working_place,
          working_place: resource, employee: employee, effective_at: effective_at)
      end

      context 'when there is EmployeeWorking Place with the same resource after' do
        let(:effective_at) { Time.now - 1.year }

        it_behaves_like 'The same resource after effective at in create'
      end

      context 'when there is EmployeeWorkingPlace with the same resource before' do
        let(:effective_at) { Time.now - 3.years }

        it_behaves_like 'The same resource before effective at in create'
      end

      context 'and the same resource is after and before new effective_at' do
        let(:effective_at) { Time.now - 3.years }
        let!(:newest_resource) do
          related_resource.dup.tap { |resource| resource.update!(effective_at: Time.now ) }
        end

        it_behaves_like 'The same resource after and before effective at in create'
      end
    end

    context 'when EmployeeWorkingPlace is updated' do
      let(:new_working_place) { create(:working_place, account: account) }
      let(:join_table_resource) { related_resource }
      let(:join_tables) { employee.employee_working_places.where('id != ?', related_resource.id) }
      let!(:new_resources) do
        [Time.now - 3.years, Time.now - 1.year, Time.now + 1.year].map do |date|
          create(:employee_working_place,
            employee: employee, effective_at: date, working_place: new_working_place)
        end
      end
      let!(:related_resource) do
        create(:employee_working_place,
          working_place: resource, employee: employee, effective_at: Time.now)
      end

      context 'and the same resource is after old effective_at' do
        it_behaves_like 'The same resource after previous effective_at'
      end

      context 'the same resources in new effective_at' do
        let!(:same_resource_tables) do
          [Time.now - 4.years, Time.now - 2.years].map do |date|
            create(:employee_working_place,
              employee: employee, effective_at: date, working_place: related_resource.working_place)
          end
        end

        context 'and the same resource is after and before new effective_at' do
          it_behaves_like 'The same resource is after and before new effective_at'
        end

        context 'and the same resource is after and before new effective_at with reasign' do
          let(:new_effective_at) { Time.now - 3.years }

          it_behaves_like 'The same resource is after and before new effective_at with reasign'
        end
      end
    end
  end
end
