require "rails_helper"

RSpec.describe Payments::UpdateSubscriptionQuantity, type: :job do
  include_context "shared_context_timecop_helper"

  let(:tomorrow) { Time.zone.tomorrow }
  let(:account_1)   { create(:account) }
  let(:employees_1) { create_list(:employee, 3, account: account_1) }

  let(:plans) do
    ["master-plan", "super-plan", "ultra-plan"].map do |plan_id|
      StripePlan.new(plan_id, 500, "chf", "month", plan_id.titleize)
    end
  end

  let!(:subscription_items) do
    [
      StripeSubscriptionItem.new(SecureRandom.hex, plans.first, 3),
      StripeSubscriptionItem.new(SecureRandom.hex, plans.second, 3),
      StripeSubscriptionItem.new(SecureRandom.hex, plans.third, 3),
    ]
  end

  subject(:job) { described_class.perform_now }

  before do
    invoice_date = Time.new(2016, 3, 1, 12, 25, 00, "+00:00").to_i
    allow(Stripe::SubscriptionItem).to receive(:list).and_return(subscription_items)
    allow(Stripe::Invoice).to receive_message_chain(:upcoming, :date).and_return(invoice_date)
  end

  shared_examples "does not change quantity" do
    it { expect { job }.to_not change { subscription_items.first.quantity } }
    it { expect { job }.to_not change { subscription_items.second.quantity } }
    it { expect { job }.to_not change { subscription_items.third.quantity } }
  end

  shared_examples "changes quantity by" do |quantity|
    it { expect { job }.to change { subscription_items.first.quantity }.by(quantity) }
    it { expect { job }.to change { subscription_items.second.quantity }.by(quantity) }
    it { expect { job }.to change { subscription_items.third.quantity }.by(quantity) }
  end

  shared_examples "events updated in different date" do |date|
    before do
      Employee::Event.update_all(effective_at: 14.days.from_now, updated_at: date)
    end

    it { expect(account_1.employees.chargeable_at_date(tomorrow).count).to eq(0) }

    it "does not update quantity for any account" do
      expect(Stripe::SubscriptionItem).to receive(:list).exactly(0).times
      job
    end

    it_behaves_like "does not change quantity"
  end

  shared_examples "events updated in last 24 hours" do |date|
    before do
      Employee::Event.update_all(effective_at: 14.days.from_now, updated_at: date)
    end

    it "does not update quantity for any account" do
      expect(Stripe::SubscriptionItem).to receive(:list).exactly(1).times
      job
    end
  end

  shared_examples "proration_date is set for tomorrow" do
    let(:proration_date) { DateTime.new(2016, 1, 2, 12, 25, 00, "UTC").to_i }

    it { expect { job }.to change { subscription_items.first.proration_date }.to(proration_date) }
    it { expect { job }.to change { subscription_items.second.proration_date }.to(proration_date) }
    it { expect { job }.to change { subscription_items.third.proration_date }.to(proration_date) }
  end

  context "new events" do
    let!(:events_1) do
      employees_1.map do |employee|
        employee.events.find_by(event_type: "hired").update!(effective_at: tomorrow)
      end
    end

    context "events with effective_at tomorrow" do
      context "quantity matches the employees count" do
        it { expect(account_1.employees.chargeable_at_date(tomorrow).count).to eq(3) }

        it "updates quantity for 1 account" do
          expect(Stripe::SubscriptionItem).to receive(:list).exactly(1).times
          job
        end

        it_behaves_like "does not change quantity"
      end

      context "new employee is hired tomorrow" do
        let(:new_employee_1) { create(:employee, account: account_1) }
        let!(:new_hired_event) do
          new_employee_1.events.find_by(event_type: "hired").update!(effective_at: tomorrow)
        end

        it { expect(account_1.employees.chargeable_at_date(tomorrow).count).to eq(4) }

        it "updates quantity for 1 account" do
          expect(Stripe::SubscriptionItem).to receive(:list).exactly(1).times
          job
        end

        it_behaves_like "changes quantity by", 1
        it_behaves_like "proration_date is set for tomorrow"
      end

      context "employee leaves company tomorrow" do
        # TODO: This should be changed to proper contract_end event later
        #       when we have this implemented and merged because right now
        #       I'm just updating it without validations
        before { account_1.employees.last.events.last.update_attribute(:event_type, "contract_end") }

        it { expect(account_1.employees.chargeable_at_date(tomorrow).count).to eq(2) }

        it "updates quantity for 1 account" do
          expect(Stripe::SubscriptionItem).to receive(:list).exactly(1).times
          job
        end

        it_behaves_like "changes quantity by", -1
        it_behaves_like "proration_date is set for tomorrow"
      end

      context "more accouts have events" do
        let(:account_2)   { create(:account) }
        let(:employees_2) { create_list(:employee, 3, account: account_2) }
        let!(:events_2) do
          employees_2.map do |employee|
            employee.events.find_by(event_type: "hired").update!(effective_at: tomorrow)
          end
        end

        it "updates quantity for 2 accounts" do
          expect(Stripe::SubscriptionItem).to receive(:list).exactly(2).times
          job
        end

        context "run job for single account" do
          subject(:job_for_single_account) { described_class.perform_now(account_2) }

          it "updates quantity for one account" do
            expect(Stripe::SubscriptionItem).to receive(:list).exactly(1).times
            job_for_single_account
          end
        end
      end
    end

    context "when event was updated" do
      let!(:subscription_items) do
        [
          StripeSubscriptionItem.new(SecureRandom.hex, plans.first, 2),
          StripeSubscriptionItem.new(SecureRandom.hex, plans.second, 2),
          StripeSubscriptionItem.new(SecureRandom.hex, plans.third, 2),
        ]
      end

      context "there are no events updated in last 24 hours" do
        context "events updated tomorrow" do
          it_behaves_like "events updated in different date", Time.zone.tomorrow
          it_behaves_like "proration_date is set for tomorrow"
        end

        context "events updated today after 00:00:00" do
          it_behaves_like "events updated in different date", Time.zone.today + 30.minutes
          it_behaves_like "proration_date is set for tomorrow"
        end

        context "events updated before yesterday" do
          it_behaves_like "events updated in different date", 2.days.ago
          it_behaves_like "proration_date is set for tomorrow"
        end

        context "events updated after tomorrow" do
          it_behaves_like "events updated in different date", 2.days.from_now
          it_behaves_like "proration_date is set for tomorrow"
        end
      end

      context "there are updated events" do
        context "event upated yesterday at 00:00:00" do
          it_behaves_like "events updated in different date", Time.zone.yesterday
          it_behaves_like "proration_date is set for tomorrow"
        end

        context "event upated yesterday after 00:00:00" do
          it_behaves_like "events updated in different date", Time.zone.yesterday + 6.hours
          it_behaves_like "proration_date is set for tomorrow"
        end

        context "event upated today at 00:00:00" do
          it_behaves_like "events updated in different date", Time.zone.today
          it_behaves_like "proration_date is set for tomorrow"
        end

        context "event upated right before today" do
          it_behaves_like "events updated in different date", Time.zone.today - 5.minutes
          it_behaves_like "proration_date is set for tomorrow"
        end
      end

      context "effective_at updated to the future" do
        before do
          Employee::Event.last.update!(effective_at: 14.days.from_now, updated_at: 6.hours.ago)
        end

        it { expect(account_1.employees.chargeable_at_date(tomorrow).count).to eq(2) }

        it_behaves_like "does not change quantity"
      end

      context "effective_at updated to the past" do
        before do
          Employee::Event.last.update!(effective_at: 14.days.ago, updated_at: 6.hours.ago)
        end

        it { expect(account_1.employees.chargeable_at_date(tomorrow).count).to eq(3) }

        it_behaves_like "changes quantity by", 1
        it_behaves_like "proration_date is set for tomorrow"
      end
    end
  end

  context "events were in the past and now are in the future" do
    let!(:events_1) do
      employees_1.map do |employee|
        employee.events.find_by(event_type: "hired").update!(effective_at: 14.days.ago)
      end
    end

    before do
      Employee::Event.update_all(updated_at: 6.hours.ago, effective_at: 14.days.from_now)
    end

    it "updates quantity for 1 account" do
      expect(Stripe::SubscriptionItem).to receive(:list).exactly(1).times
      job
    end

    it_behaves_like "changes quantity by", -3
    it_behaves_like "proration_date is set for tomorrow"
  end

  context "events were in the future and now are in the past" do
    let!(:events_1) do
      employees_1.map do |employee|
        employee.events.find_by(event_type: "hired").update!(effective_at: 14.days.from_now)
      end
    end

    let!(:subscription_items) do
      [
        StripeSubscriptionItem.new(SecureRandom.hex, plans.first, 0),
        StripeSubscriptionItem.new(SecureRandom.hex, plans.second, 0),
        StripeSubscriptionItem.new(SecureRandom.hex, plans.third, 0),
      ]
    end

    before do
      Employee::Event.update_all(updated_at: 6.hours.ago, effective_at: 14.days.ago)
    end

    it "updates quantity for 1 account" do
      expect(Stripe::SubscriptionItem).to receive(:list).exactly(1).times
      job
    end

    it_behaves_like "changes quantity by", 3
    it_behaves_like "proration_date is set for tomorrow"
  end
end
