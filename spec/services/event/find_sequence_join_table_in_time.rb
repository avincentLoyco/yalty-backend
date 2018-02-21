require "rails_helper"

RSpec.describe FindSequenceJoinTableInTime, type: :service do
  include_context "shared_context_account_helper"

  subject do
    described_class.new(
      join_tables, new_effective_at, resource, join_table_resource
    ).call
  end

  let(:account) { create(:account) }
  let(:new_effective_at) { 2.years.ago }
  let(:join_table_resource) { nil }
  let(:employee) { create(:employee, account: account) }

  shared_examples "No employee join tables" do
    it { expect(subject).to eq [] }
  end

  shared_examples "The same resource after effective at in create" do
    it { expect(subject).to include related_resource }
  end

  shared_examples "The same resource before effective at in create" do
    it { expect(subject).to eq [] }
  end

  shared_examples "The same resource after and before effective at in create" do
    it { expect(subject).to include newest_resource }
    it { expect(subject).to_not include related_resource }
  end

  shared_examples "The same resource after previous effective_at" do
    it { expect(subject).to include new_resources.last }
    it { expect(subject).to_not include new_resources.first }
    it { expect(subject).to_not include new_resources.second }
  end

  shared_examples "The same resource is after and before new effective_at" do
    it { expect(subject).to include new_resources.last }
    it { expect(subject).to include same_resource_tables.last }
    it { expect(subject).to_not include new_resources.first }
  end

  shared_examples "The same resource is after and before new effective_at with reasign" do
    it { expect(subject).to include new_resources.last }
    it { expect(subject).to include same_resource_tables.last }
    it { expect(subject).to include new_resources.first }
  end

  shared_examples "The same resource at new effective_at" do
    it { expect { subject }.to raise_error(API::V1::Exceptions::InvalidResourcesError) }
  end

  context "For EmployeeWorkingPlaces" do
    let(:resource_class) { "working_place_id" }
    let(:resource) { create(:working_place, account: account) }
    let(:join_tables) { employee.employee_working_places.reload }

    context "when there are no EmployeeWorkingPlaces with the same resource" do
      it_behaves_like "No employee join tables"
    end

    context "when EmployeeWorkingPlace is created" do
      let!(:related_resource) do
        create(:employee_working_place,
          working_place: resource, employee: employee, effective_at: effective_at)
      end

      context "when there is EmployeeWorking Place with the same resource after" do
        let(:effective_at) { 1.year.ago }

        it_behaves_like "The same resource after effective at in create"
      end

      context "when there is EmployeeWorkingPlace with the same resource before" do
        let(:effective_at) { 3.years.ago }

        it_behaves_like "The same resource before effective at in create"
      end

      context "and the same resource is after and before new effective_at" do
        let(:effective_at) { 3.years.ago }
        let!(:newest_resource) do
          related_resource.dup.tap { |resource| resource.update!(effective_at: Time.now ) }
        end

        it_behaves_like "The same resource after and before effective at in create"
      end
    end

    context "when EmployeeWorkingPlace is updated" do
      let(:new_working_place) { create(:working_place, account: account) }
      let(:join_table_resource) { related_resource }
      let(:join_tables) { employee.employee_working_places.where("id != ?", related_resource.id) }
      let!(:new_resources) do
        [3.years.ago, 1.year.ago, 1.year.since].map do |date|
          create(:employee_working_place,
            employee: employee, effective_at: date, working_place: new_working_place)
        end
      end
      let!(:related_resource) do
        create(:employee_working_place,
          working_place: resource, employee: employee, effective_at: Time.now)
      end

      context "and the same resource is after old effective_at" do
        it_behaves_like "The same resource after previous effective_at"
      end

      context "the same resources in new effective_at" do
        let!(:same_resource_tables) do
          [4.years.ago, 2.years.ago].map do |date|
            create(:employee_working_place,
              employee: employee, effective_at: date, working_place: other_working_place)
          end
        end

        context "and the same resource is after and before new effective_at" do
          let(:other_working_place) { create(:working_place, account: account) }

          it_behaves_like "The same resource is after and before new effective_at"
        end

        context "and the same resource is after and before new effective_at with reasign" do
          let(:other_working_place) { related_resource.working_place }
          let(:new_effective_at) { 3.years.ago }

          it_behaves_like "The same resource is after and before new effective_at with reasign"
        end

        context "and the same resource in new effective_at" do
          let(:other_working_place) { create(:working_place, account: account) }
          let(:join_table_resource) { same_resource_tables.first }
          let(:resource) { same_resource_tables.first.working_place }

          it_behaves_like "The same resource at new effective_at"
        end
      end
    end
  end

  context "For EmployeeTimeOffPolicy" do
    let(:resource_class) { "time_off_policy_id" }
    let(:category) { create(:time_off_category, account: account) }
    let(:resource) { create(:time_off_policy, time_off_category: category) }
    let(:join_tables) { employee.employee_time_off_policies }

    context "when there are EmployeeTimeOffPolicy with the same resource" do
      it_behaves_like "No employee join tables"
    end

    context "when EmployeeTimeOffPolicy is created" do
      let!(:related_resource) do
        create(:employee_time_off_policy,
          time_off_policy: resource, employee: employee, effective_at: effective_at)
      end

      context "when there is EmployeeTimeOffPolicy with the same resource after" do
        let(:effective_at) { 1.year.ago }

        it_behaves_like "The same resource after effective at in create"
      end

      context "when there is EmployeeTimeOffPolicy with the same resource before" do
        let(:effective_at) { 3.years.ago }

        it_behaves_like "The same resource before effective at in create"
      end

      context "and the same resource is after and before new effective_at" do
        let(:effective_at) { 3.years.ago }
        let!(:newest_resource) do
          related_resource.dup.tap { |resource| resource.update!(effective_at: Time.now ) }
        end

        it_behaves_like "The same resource after and before effective at in create"
      end
    end

    context "when EmployeeTimeOffPolicy is updated" do
      let(:new_policy) { create(:time_off_policy, time_off_category: category) }
      let(:join_table_resource) { related_resource }
      let(:join_tables) { employee.employee_time_off_policies.where("id != ?", related_resource.id) }
      let!(:new_resources) do
        [3.years.ago, 1.year.ago, 1.year.since].map do |date|
          create(:employee_time_off_policy,
            employee: employee, effective_at: date, time_off_policy: new_policy)
        end
      end
      let!(:related_resource) do
        create(:employee_time_off_policy,
          time_off_policy: resource, employee: employee, effective_at: Time.now)
      end

      context "and the same resource is after old effective_at" do
        it_behaves_like "The same resource after previous effective_at"
      end

      context "the same resources in new effective_at" do
        let!(:same_resource_tables) do
          [4.years.ago, 2.years.ago].map do |date|
            create(:employee_time_off_policy,
              employee: employee, effective_at: date, time_off_policy: other_policy)
          end
        end

        context "and the same resource is after and before new effective_at" do
          let(:other_policy) { create(:time_off_policy, time_off_category: category) }

          it_behaves_like "The same resource is after and before new effective_at"
        end

        context "and the same resource is after and before new effective_at with reasign" do
          let(:other_policy) { related_resource.time_off_policy }
          let(:new_effective_at) { 3.years.ago }

          it_behaves_like "The same resource is after and before new effective_at with reasign"
        end

        context "and the same resource in new effective_at" do
          let(:other_policy) { create(:time_off_policy, time_off_category: category) }
          let(:join_table_resource) { same_resource_tables.first }
          let(:resource) { same_resource_tables.first.time_off_policy }

          it_behaves_like "The same resource at new effective_at"
        end
      end
    end
  end

  context "For EmployeePresencePolicy" do
    let(:resource) { create(:presence_policy, :with_presence_day, account: account) }
    let(:join_tables) { employee.employee_presence_policies }

    context "when there are EmployeePresencePolicies with the same resource" do
      it_behaves_like "No employee join tables"
    end

    context "when EmployeePresencePolicy is created" do
      let!(:related_resource) do
        create(:employee_presence_policy,
          presence_policy: resource, employee: employee, effective_at: effective_at)
      end

      context "when there is EmployeePresencePolicy with the same resource after" do
        let(:effective_at) { 1.year.ago }

        it_behaves_like "The same resource after effective at in create"
      end

      context "when there is EmployeePresencePolicy with the same resource before" do
        let(:effective_at) { 3.years.ago }

        it_behaves_like "The same resource before effective at in create"
      end

      context "and the same resource is after and before new effective_at" do
        let(:effective_at) { 3.years.ago }
        let!(:newest_resource) do
          related_resource.dup.tap { |resource| resource.update!(effective_at: Time.now ) }
        end

        it_behaves_like "The same resource after and before effective at in create"
      end
    end

    context "when EmployeePresencePolicy is updated" do
      let(:new_policy) { create(:presence_policy, :with_presence_day, account: account) }
      let(:join_table_resource) { related_resource }
      let(:join_tables) { employee.employee_presence_policies.where("id != ?", related_resource.id) }
      let!(:new_resources) do
        [3.years.ago, 1.year.ago, 1.year.since].map do |date|
          create(:employee_presence_policy,
            employee: employee, effective_at: date, presence_policy: new_policy)
        end
      end
      let!(:related_resource) do
        create(:employee_presence_policy,
          presence_policy: resource, employee: employee, effective_at: Time.now)
      end

      context "and the same resource is after old effective_at" do
        it_behaves_like "The same resource after previous effective_at"
      end

      context "the same resources in new effective_at" do
        let!(:same_resource_tables) do
          [4.years.ago, 2.years.ago].map do |date|
            create(:employee_presence_policy,
              employee: employee, effective_at: date, presence_policy: other_policy)
          end
        end

        context "and the same resource is after and before new effective_at" do
          let(:other_policy) { create(:presence_policy, :with_presence_day, account: account) }

          it_behaves_like "The same resource is after and before new effective_at"
        end

        context "and the same resource is after and before new effective_at with reasign" do
          let(:other_policy) { related_resource.presence_policy }
          let(:new_effective_at) { 3.years.ago }

          it_behaves_like "The same resource is after and before new effective_at with reasign"
        end

        context "and the same resource in new effective_at" do
          let(:other_policy) { create(:presence_policy, :with_presence_day, account: account) }
          let(:join_table_resource) { same_resource_tables.first }
          let(:resource) { same_resource_tables.first.presence_policy }

          it_behaves_like "The same resource at new effective_at"
        end
      end
    end
  end
end
