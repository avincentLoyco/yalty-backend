require 'rails_helper'

RSpec.describe API::V1::Payments::PlansController, type: :controller do
  include_context 'shared_context_headers'
  include_context 'shared_context_timecop_helper'

  let(:customer_id)  { 'cus_123' }
  let(:plan_id)      { 'super-plan' }
  let(:plan)         { StripePlan.new('super-plan', 500, 'chf', 'month', 'Super Plan') }
  let(:invoice_date) { Time.new(2016, 1, 1, 12, 25, 00, '+00:00').to_i }
  let(:subscription) { StripeSubscription.new('sub_123', invoice_date) }

  let(:sub_item) do
    si = Stripe::SubscriptionItem.new(id: 'si_123')
    si.plan = plan
    si
  end
  let(:sub_items)   { [sub_item] }

  before do
    account.update(customer_id: customer_id)
    user.update(role: 'account_owner')
    allow(Stripe::SubscriptionItem).to receive(:create).and_return(sub_item)
    allow(Stripe::SubscriptionItem).to receive(:list).and_return(sub_items)
    allow(Stripe::Invoice).to receive_message_chain(:upcoming, :date).and_return(invoice_date)
    allow(Stripe::Subscription).to receive(:retrieve).and_return(subscription)
    allow(sub_item).to receive(:delete).with(proration_date: invoice_date)
  end

  shared_examples_for 'errors' do |controller_method|
    subject(:shared_subject) do
      if controller_method.eql?(:create)
        post controller_method, id: plan_id
      else
        delete controller_method, id: plan_id
      end
    end

    context 'Stripe error' do
      before do
        allow(Stripe::SubscriptionItem).to receive(:create).and_raise(Stripe::APIError)
        allow(Stripe::SubscriptionItem).to receive(:list).and_raise(Stripe::APIError)
        shared_subject
      end

      it { expect(response.status).to eq(502) }
      it { expect(JSON.parse(response.body)['errors'].first['type']).to eq('plan') }
    end

    context 'when there is no customer_id' do
      let(:customer_id) { nil }
      before { shared_subject }

      it { expect(response.status).to eq(502) }
      it { expect(JSON.parse(response.body)['errors'].first['type']).to eq('account') }
      it { expect_json(regex('Customer is not created')) }
    end

    context 'when User is administrator' do
      before do
        user.update(role: 'account_administrator')
        shared_subject
      end

      it { expect(response.status).to eq(403) }
    end

    context 'when User is regular user' do
      before do
        user.update(role: 'user')
        shared_subject
      end

      it { expect(response.status).to eq(403) }
    end
  end

  describe '#POST /v1/payments/plans' do
    subject(:create_plan) { post :create, id: plan_id }

    shared_examples_for 'success POST response' do
      context 'response' do
        let(:expected_json) do
          {
            id: plan.id,
            amount: plan.amount,
            currency: plan.currency,
            interval: plan.interval,
            name: plan.name,
            active: true
          }
        end

        before { create_plan }

        it { expect(response.status).to eq(200) }
        it { expect_json(expected_json) }
      end
    end

    context 'success' do
      context 'subscribe to first plan' do
        before { account.update(available_modules: ::Payments::AvailableModules.new) }

        it_should_behave_like 'success POST response'

        it 'should not prorate subscription' do
          expect(Stripe::SubscriptionItem)
            .to receive(:create)
            .with(hash_including(prorate: false))
          create_plan
        end

        it 'should add plan to available_modules' do
          expect { create_plan }
            .to change { account.reload.available_modules.all }
            .from([])
            .to([plan_id])
        end
      end

      context 'subscribe to second plan' do
        before do
          modules = [::Payments::PlanModule.new(id: 'any-plan', canceled: false)]
          account.update(available_modules: ::Payments::AvailableModules.new(data: modules))
        end

        it_should_behave_like 'success POST response'

        it 'should prorate subscription' do
          expect(Stripe::SubscriptionItem)
            .to receive(:create)
            .with(hash_including(prorate: true))
          create_plan
        end

        it 'should add plan to available_modules' do
          expect { create_plan }
            .to change { account.reload.available_modules.size }
            .from(1)
            .to(2)
        end
      end

      context 'subscribe again to active plan' do
        before do
          modules = [
            ::Payments::PlanModule.new(id: 'any-plan', canceled: false),
            ::Payments::PlanModule.new(id: plan_id, canceled: true)
          ]
          account.update(available_modules: ::Payments::AvailableModules.new(data: modules))
        end

        it_should_behave_like 'success POST response'

        it 'should reactivate plan' do
          expect { create_plan }
            .to change { account.reload.available_modules.canceled.any? }
            .from(true)
            .to(false)
        end

        it 'should not create new SubscriptionItem' do
          expect(Stripe::SubscriptionItem).to_not receive(:create)
          create_plan
        end

        it 'should find existing SubscriptionItem' do
          expect(Stripe::SubscriptionItem).to receive(:list)
          create_plan
        end
      end
    end

    context 'errors' do
      context 'when params are invalid' do
        let(:params_error) { JSON.parse(response.body).fetch('errors').first }

        context 'param is missing' do
          before { post :create }

          it { expect(response.status).to eq(422) }
          it { expect(params_error['field']).to eq('id') }
          it { expect(params_error['messages']).to eq(['is missing']) }
        end

        context 'param is nil' do
          let(:plan_id) { nil }

          before { create_plan }

          it { expect(response.status).to eq(422) }
          it { expect(params_error['field']).to eq('id') }
          it { expect(params_error['messages']).to eq(['must be filled']) }
        end
      end

      context 'when we subscribe to first plan' do
        context 'and account save fails' do
          before { allow(account).to receive(:save!).and_raise('Cannot save') }

          it { expect(Stripe::SubscriptionItem).to_not have_received(:create) }
          it { expect { create_plan }.to_not change { account.reload.available_modules.data } }
        end

        context 'and Stripe fails' do
          before do
            allow(Stripe::SubscriptionItem)
              .to receive(:create)
              .and_raise(Stripe::InvalidRequestError)
          end

          it { expect { create_plan }.to_not change { account.reload.available_modules.data } }
        end
      end

      context 'when plan is already active' do
        before do
          modules = [::Payments::PlanModule.new(id: plan_id, canceled: true)]
          account.update(available_modules: ::Payments::AvailableModules.new(data: modules))
        end

        context 'and account update fails' do
          before { allow(account).to receive(:save!).and_raise('Cannot save') }

          it { expect(Stripe::SubscriptionItem).to_not have_received(:list) }
          it { expect { create_plan }.to_not change { account.reload.available_modules.canceled } }
        end

        context 'and Stripe fails' do
          before do
            allow(Stripe::SubscriptionItem).to receive(:list).and_raise(Stripe::InvalidRequestError)
          end

          it { expect { create_plan }.to_not change { account.reload.available_modules.canceled } }
        end
      end

      it_should_behave_like 'errors', :create
    end
  end

  describe '#DELETE /v1/payments/plans' do
    subject(:delete_plan) { delete :destroy, id: plan_id }

    shared_examples_for 'success DELETE response' do
      context 'response' do
        let(:expected_json) do
          {
            id: plan.id,
            amount: plan.amount,
            currency: plan.currency,
            interval: plan.interval,
            name: plan.name,
            active: false
          }
        end

        before { delete_plan }

        it { expect(response.status).to eq(200) }
        it { expect_json(expected_json) }
      end
    end

    context 'success' do
      before do
        modules = [::Payments::PlanModule.new(id: plan.id, canceled: false)]
        account.update(available_modules: ::Payments::AvailableModules.new(data: modules))
      end

      context 'removing plan' do
        it_should_behave_like 'success DELETE response'

        it 'does not remove SubscriptionItem' do
          expect_any_instance_of(Stripe::SubscriptionItem).to_not receive(:delete)
          delete_plan
        end

        it 'returns existing plan from Stripe' do
          expect(Stripe::SubscriptionItem).to receive(:list)
          delete_plan
        end

        it 'changes canceled status' do
          expect { delete_plan }
            .to change { account.reload.available_modules.canceled.empty? }
            .from(true)
            .to(false)
        end
      end
    end

    context 'errors' do
      it_should_behave_like 'errors', :destroy

      context 'when account update fails' do
        before { allow(account).to receive(:update!).and_raise('Cannot update') }

        it { expect { delete_plan }.to_not change { account.reload.available_modules.data } }
        it { expect(Stripe::SubscriptionItem).to_not receive(:list) }
      end
    end
  end
end
