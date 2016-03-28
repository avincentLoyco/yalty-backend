require 'rails_helper'

RSpec.describe AssignJoinTableCollection, type: :service do
  let(:employee) { create(:employee) }

  describe "#call" do
    context "with valid attributes" do
      context " and models that have a join table" do
        let(:employee_time_off_policy) do
          create(:employee_time_off_policy, employee: employee)
        end

        context "updates the collection association of the resource" do
          let(:time_off_policies_id_hash) { create_list(:time_off_policy, 2).map{ |t| { id: t.id} } }

          before {employee_time_off_policy}

          it "when it is given an non empty array" do
            expect {
              described_class.new(employee, time_off_policies_id_hash, "time_off_policies").call
            }.to change {
              EmployeeTimeOffPolicy.count
            }.by(1)
          end

          context "when it is given an empty array" do
            it '' do
              expect{
                described_class.new(employee, [], "time_off_policies").call
              }.to change {
                EmployeeTimeOffPolicy.count
              }.by(-1)
            end
            it '' do
              expect{
                described_class.new(employee, [], "time_off_policies").call
              }.not_to change {
                TimeOffPolicy.count
              }
            end
          end
        end
      end

      context " and models that do not have a join table" do
        let(:holiday_policiess_id_hash) { create_list(:holiday_policy, 2).map{ |t| { id: t.id} } }
        it "raises an error" do
          expect{described_class.new(employee, holiday_policiess_id_hash, "holiday_policies").call}.
            to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end

    context "with invalid attributes raises an error" do
      let(:wrong_attributes) { ["a"] }
      let(:param_with_wrong_id) { [{ id: "1111 2222 3333 4444"}] }

      it "when there is a wrong collection_name" do
        expect{ described_class.new(employee, [], "wrong_attributes").call }.
          to raise_error(NameError)
      end

      it "when there is a wrong collection" do
        expect{ described_class.new(employee, wrong_attributes, "time_off_policies").call }.
          to raise_error(TypeError)
      end

      it "where there is a wrong id for a correct collection" do
        expect{ described_class.new(employee, param_with_wrong_id , "time_off_policies").call }.
          to raise_error(ActiveRecord::RecordInvalid)
      end

      it "when there is a wrong resource" do
        expect{ described_class.new('wrong_resource', [], "time_off_policies").call }.
          to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
