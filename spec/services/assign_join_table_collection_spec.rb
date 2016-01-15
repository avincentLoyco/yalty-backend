require 'rails_helper'

RSpec.describe AssignJoinTableCollection, type: :service do
  let(:employee) { create(:employee) }

  describe "#call" do
    context "with valid attributes" do
      context " and models that have a join table" do
        let(:employee_time_off_policie) do
          create(:employee_time_off_policy, employee: employee)
        end

        context "updates the collection association of the resource" do
          let(:time_off_policies_id_hash) do
            create_list(:time_off_policy, 2).map{ |t| { id: t.id} }
          end

          before {employee_time_off_policie}

          it "when it is given an non empty array" do
            expect {
              described_class.new(employee, time_off_policies_id_hash, "time_off_policies").call
            }.to change {
              EmployeeTimeOffPolicy.count
            }.by(1)
          end

          it "when it is given an empty array" do
            expect{
              described_class.new(employee, [], "time_off_policies").call
            }.to change {
              EmployeeTimeOffPolicy.count
            }.by(-1)
          end
        end
      end

      context " and models that do not have a join table" do
        let(:time_offs_id_hash) { create_list(:time_off, 2).map{ |t| { id: t.id} } }
        it "raises an error" do
          expect{described_class.new(employee, time_offs_id_hash, "time_offs").call}.
            to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end

    context "with invalid attributes raises an error" do
      let(:wrong_attributes) { ["a"] }

      it "when there is a wrong collection_name" do
        expect{ described_class.new(employee, [], "wrong_attributes").call }.
          to raise_error(ActiveRecord::RecordNotFound)
      end

      it "when there is a wrong collection" do
        expect{ described_class.new(employee, wrong_attributes, "time_off_policies").call }.
          to raise_error(TypeError)
      end

      it "when there is a wrong resource" do
        expect{ described_class.new('wrong_resource', [], "time_off_policies").call }.
          to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
