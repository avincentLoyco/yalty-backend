require "rails_helper"

RSpec.describe API::V1::RegisteredWorkingTimesController, type: :controller do
  include_context "shared_context_headers"

  describe "#create" do
    subject { post :create, params }
    let(:employee) { create(:employee, account: Account.current) }
    let(:employee_id) { employee.id }
    let(:date) { "1/4/2016" }
    let(:first_start_time) { "15:00" }
    let(:first_end_time) { "19:00" }
    let(:params) do
      {
        employee_id: employee_id,
        date: date,
        time_entries: time_entries_params,
        comment: comment,
      }
    end
    let(:time_entries_params) do
      [
        {
          "start_time" =>"11:00",
          "end_time" => "15:00",
          "type" => "working_time",
        },
        {
          "start_time" => first_start_time,
          "end_time" => first_end_time,
          "type" => "working_time",
        },
      ]
    end
    let(:comment) { nil }

    context "with valid params" do
      shared_examples "Authorized employee" do
        before { Account::User.current.update!(role: "user", employee: employee) }

        it { is_expected.to have_http_status(204) }
      end

      context "when data for time entries is nil" do
        let(:time_entries_params) { nil }

        it { is_expected.to have_http_status(422) }
      end

      context "when data for time entries is empty" do
        let(:time_entries_params) { [] }

        it { expect { subject }.to change { employee.registered_working_times.count }.by(1) }

        it { is_expected.to have_http_status(204) }
        it_behaves_like "Authorized employee"
      end

      context "when registered working time for a given date does not exist" do
        it { expect { subject }.to change { RegisteredWorkingTime.count }.by(1) }
        it { expect { subject }.to change { employee.registered_working_times.count }.by(1) }

        it { is_expected.to have_http_status(204) }
        it_behaves_like "Authorized employee"
      end

      context "when time entry is from 00:00 to 24:00" do
        let(:time_entries_params) { [{ start_time: "00:00:00", end_time: "24:00:00" }] }

        it { expect { subject }.to change { RegisteredWorkingTime.count }.by(1) }
        it { expect { subject }.to change { employee.registered_working_times.count }.by(1) }
        it do
          subject

          expect(RegisteredWorkingTime.first.time_entries)
            .to eq([{"start_time"=>"00:00:00", "end_time"=>"24:00:00"}])
        end
      end

      context "when registered working time for a given date exists" do
        let!(:registered_working_time) do
          create(:registered_working_time, employee: employee, date: date)
        end

        it { expect { subject }.to_not change { RegisteredWorkingTime.count } }
        it { expect { subject }.to change { registered_working_time.reload.time_entries } }

        it { is_expected.to have_http_status(204) }
        it_behaves_like "Authorized employee"

        it "should have new time entries" do
          subject

          expect(registered_working_time.reload.time_entries).to include(
            "start_time" =>"11:00", "end_time" =>"15:00",
          )

          expect(registered_working_time.reload.time_entries).to include(
            "start_time" =>"15:00", "end_time" =>"19:00",
          )
        end
      end

      context "when the comment param is present but empty" do
        let(:comment) { "" }

        it { expect { subject }.to change { RegisteredWorkingTime.count }.by(1) }
        it { expect { subject }.to change { employee.registered_working_times.count }.by(1) }

        it { is_expected.to have_http_status(204) }
        it_behaves_like "Authorized employee"
      end

      context "when the comment param is present and is not empty" do
        let(:comment) { "A comment about working day" }

        it { expect { subject }.to change { RegisteredWorkingTime.count }.by(1) }
        it { expect { subject }.to change { employee.registered_working_times.count }.by(1) }

        it { is_expected.to have_http_status(204) }
        it_behaves_like "Authorized employee"

        it "should have new comment" do
          subject

          registered_working_time = employee.registered_working_times.where(date: Date.parse(date)).first!

          expect(registered_working_time.reload.comment).to eql("A comment about working day")
        end
      end

      context "when registred working time exist and we add a comment" do
        let!(:registered_working_time) do
          create(:registered_working_time, employee: employee, date: date, comment: "Old comment")
        end
        let(:comment) { "A comment about working day" }

        it { expect { subject }.to_not change { RegisteredWorkingTime.count } }

        it { is_expected.to have_http_status(204) }
        it_behaves_like "Authorized employee"

        it "should have new comment" do
          subject

          expect(registered_working_time.reload.comment).to eql("A comment about working day")
        end
      end
    end

    context "with invalid params" do
      context "when user is not an account manager or resource owner" do
        before { Account::User.current.update!(role: "user") }

        it { expect { subject }.to_not change { RegisteredWorkingTime.count } }
        it { is_expected.to have_http_status(403) }
      end

      context "when invalid date format send" do
        let(:date) { "abc" }

        it { expect { subject }.to_not change { RegisteredWorkingTime.count } }
        it { is_expected.to have_http_status(422) }
      end

      context "when ivalid data for time entries send" do
        context "time entries times are not valid" do
          let(:first_start_time) { "abcd" }
          let(:first_end_time) { "efgh" }

          it { expect { subject }.to_not change { RegisteredWorkingTime.count } }
          it { is_expected.to have_http_status(422) }
        end

        context "time entries times are not present" do
          let(:first_start_time) { "" }
          let(:first_end_time) { nil }

          it { expect { subject }.to_not change { RegisteredWorkingTime.count } }
          it { is_expected.to have_http_status(422) }
        end

        context "invalid time_entries keys" do
          let(:time_entries_params) do
            [
              {
                "test" =>"11:00",
                "test2" => "15:00",
              },
              [],
            ]
          end

          it { expect { subject }.to_not change { RegisteredWorkingTime.count } }
          it { is_expected.to have_http_status(422) }
        end

        context "invalid time entries format" do
          let(:time_entries_params) do
            [
              {
                "start_time" =>"11:00",
                "end_time" => "15:00",
              },
              [],
            ]
          end

          it { expect { subject }.to_not change { RegisteredWorkingTime.count } }
          it { is_expected.to have_http_status(422) }
        end
      end

      context "when invalid employee id send" do
        let(:employee_id) { "abc" }

        it { expect { subject }.to_not change { RegisteredWorkingTime.count } }
        it { is_expected.to have_http_status(404) }
      end
    end
  end
end
