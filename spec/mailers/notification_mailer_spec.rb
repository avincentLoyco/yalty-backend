require "rails_helper"

RSpec.describe NotificationMailer, type: :mailer do
  let_it_be(:employee) do
    build(
      :employee,
      :with_attributes,
      employee_attributes: { firstname: "John", lastname: "Jaworski" },
    )
  end

  let_it_be(:manager_employee) do
    build(
      :employee,
      :with_attributes,
      employee_attributes: { firstname: "Mister", lastname: "Smith" },
    )
  end

  let_it_be(:user) { build(:account_user, employee: employee) }
  let_it_be(:manager) { build(:account_user, employee: manager_employee) }
  let_it_be(:time_off_category) { build(:time_off_category, name: "other") }
  let_it_be(:time_off) do
    build(:time_off,
      time_off_category: time_off_category,
      employee: employee,
      start_time: Date.new(2018,5,1) + 8.hours,
      end_time: Date.new(2018,5,10) + 8.hours
    )
  end

  before do
    ActionMailer::Base.deliveries = []
  end

  describe "time_off_request" do
    subject(:mail) { described_class.time_off_request(manager, time_off) }

    it { expect(mail.subject).to eq("Time-off requested") }
    it { expect(mail.to).to contain_exactly manager.email }
    it { expect(mail.from).to contain_exactly ENV["YALTY_APP_EMAIL"] }
    it { expect(mail.body).to include("Mister Smith") }
    it { expect(mail.body).to include("from May 01, 2018 08:00") }
    it { expect(mail.body).to include("#{manager.account.subdomain}.#{ENV["YALTY_APP_DOMAIN"]}") }
    it { expect(mail.body).to include("to May 10, 2018 08:00") }
    it { expect(mail.body).to include("John Jaworski asked") }
  end

  describe "time_off_approved" do
    subject(:mail) { described_class.time_off_approved(user, time_off) }

    it { expect(mail.subject).to eq("Time-off accepted") }
    it { expect(mail.to).to contain_exactly user.email }
    it { expect(mail.from).to contain_exactly ENV["YALTY_APP_EMAIL"] }
    it { expect(mail.body).to include("John Jaworski") }
    it { expect(mail.body).to include("from May 01, 2018 08:00") }
    it { expect(mail.body).to include("to May 10, 2018 08:00") }
    it { expect(mail.body).to include("Your absence request for Other") }
    it { expect(mail.body).to include("has been accepted") }
  end

  describe "time_off_declined" do
    subject(:mail) { described_class.time_off_declined(user, time_off) }

    it { expect(mail.subject).to eq("Time-off declined") }
    it { expect(mail.to).to contain_exactly user.email }
    it { expect(mail.from).to contain_exactly ENV["YALTY_APP_EMAIL"] }
    it { expect(mail.body).to include("John Jaworski") }
    it { expect(mail.body).to include("from May 01, 2018 08:00") }
    it { expect(mail.body).to include("to May 10, 2018 08:00") }
    it { expect(mail.body).to include("Your absence request for Other") }
    it { expect(mail.body).to include("has been declined") }
  end
end
