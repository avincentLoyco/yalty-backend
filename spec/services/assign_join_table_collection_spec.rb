require 'rails_helper'

RSpec.describe AssignJoinTableCollection, type: :service do
  let(:time_off_policy) { create(:time_off_policy) }
  let(:employee) { create(:employee) }
  let!(:employee_time_off_policy) do
    create(:employee_time_off_policy,
      employee: employee,
      time_off_policy: time_off_policy,
      effective_at: Time.zone.now
    )
  end
  describe "#call" do
    context "with valid attributes" do
      context " and models that have a join table" do
        context "updates the collection association of the resource" do
          let(:employee_time_off_policy_attribute_hash) do
            create_list(:employee, 2, account: employee.account).map do |e|
              {
                employee_id: e.id,
                effective_at: Time.zone.today,
                time_off_policy_id: time_off_policy.id
              }
            end
          end

          it "when it is given an non empty collection" do
            expect {
              described_class.new(time_off_policy, employee_time_off_policy_attribute_hash, "employees").call
            }.to change {
              EmployeeTimeOffPolicy.count
            }.by(1)
          end

          context "when it is given an empty collection and it already had associations" do
            it '' do
              expect{
                described_class.new(time_off_policy, [], "employees").call
              }.to change {
                EmployeeTimeOffPolicy.count
              }.by(-1)
            end
            it '' do
              expect{
                described_class.new(time_off_policy, [], "employees").call
              }.not_to change {
                Employee.count
              }
            end
          end
        end

        context "when trying to remove one association but it has an associated balance" do
          let!(:balance) do
            create(:employee_balance,
              time_off_category: time_off_policy.time_off_category,
              employee: employee,
              effective_at: Time.zone.now + 3.days
            )
          end
          before do
            Timecop.freeze(2016, 1, 1, 0, 0)
          end

          after do
            Timecop.return
          end
          it '' do
            expect {
              described_class.new(
                time_off_policy,
                [],
                "employees"
              ).call
            }.to raise_error(CanCan::AccessDenied)
          end
        end
      end

      context " and models that do not have a join table" do
        let(:holiday_policiess_id_hash) { create_list(:holiday_policy, 2).map{ |t| { id: t.id} } }
        it "raises an error" do
          expect{described_class.new(time_off_policy, holiday_policiess_id_hash, "holiday_policies").call}.
            to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end

    context "with invalid attributes raises an error" do
      let(:wrong_attributes) { ["a"] }
      let(:param_with_wrong_id) { [{ id: "1111 2222 3333 4444"}] }

      it "when there is a wrong collection_name" do
        expect{ described_class.new(time_off_policy, [], "wrong_attributes").call }.
          to raise_error(NameError)
      end

      it "when there is a wrong collection" do
        expect{ described_class.new(time_off_policy, wrong_attributes, "employees").call }.
          to raise_error(ArgumentError)
      end

      it "where there is a wrong id for a correct collection" do
        expect{ described_class.new(time_off_policy, param_with_wrong_id , "employees").call }.
          to raise_error(ActiveRecord::RecordInvalid)
      end

      it "when there is a wrong resource" do
        expect{ described_class.new('wrong_resource', [], "employees").call }.
          to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
