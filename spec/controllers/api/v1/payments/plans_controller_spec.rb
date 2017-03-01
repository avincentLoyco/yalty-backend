require 'rails_helper'

RSpec.describe API::V1::Payments::PlansController, type: :controller do
  include_context 'shared_context_headers'
  include_context 'shared_context_timecop_helper'

  let(:customer_id) { 'cus_123' }
  let(:plan_id)     { 'super-plan' }
  let(:plan)        { StripePlan.new('super-plan', 500, 'chf', 'month', 'Super Plan') }
  let(:sub_item)    { StripeSubscriptionItem.new('si_123', plan) }
  let(:sub_items)   { [sub_item] }

  before do
    account.update(customer_id: customer_id)
    user.update(role: 'account_owner')
    allow(Stripe::SubscriptionItem).to receive(:create).and_return(sub_item)
    allow(Stripe::SubscriptionItem).to receive_message_chain(:list, :data).and_return(sub_items)
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
        allow(Stripe::SubscriptionItem).to receive(:create).and_return(Stripe::APIError)
        allow(Stripe::SubscriptionItem).to receive(:list).and_return(Stripe::APIError)
        shared_subject
      end

      it { expect(response.status).to eq(500) }
    end

    context 'when there is no customer_id' do
      let(:customer_id) { nil }
      before { shared_subject }

      it { expect(response.status).to eq(500) }
      it { expect_json(regex('customer_id is empty')) }
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

    context 'success' do
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

      context 'response' do
        before { create_plan }

        it { expect(response.status).to eq(200) }
        it { expect_json(expected_json) }
      end

      context 'available_modules' do
        it { expect { create_plan }.to change { account.available_modules }.from([]).to([plan.id]) }
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

      context 'when account save fails' do
        before { allow(account).to receive(:save).and_raise('Cannot save') }

        it { expect { create_plan }.to_not change { account.reload.available_modules } }
        it { expect(Stripe::SubscriptionItem).to_not receive(:create) }
      end

      context 'when Stripe fails' do
        before do
          allow(Stripe::SubscriptionItem).to receive(:create).and_raise(Stripe::InvalidRequestError)
        end

        it { expect { create_plan }.to_not change { account.reload.available_modules } }
      end

      it_should_behave_like 'errors', :create
    end
  end

  describe '#DELETE /v1/payments/plans' do
    subject(:delete_plan) { delete :destroy, id: plan_id }

    context 'success' do
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

      before { account.update(available_modules: [plan_id]) }

      context 'response' do
        before { delete_plan }

        it { expect(response.status).to eq(200) }
        it { expect_json(expected_json) }
      end

      context 'available_modules' do
        it { expect { delete_plan }.to change { account.available_modules }.from([plan.id]).to([]) }
      end
    end

    context 'errors' do
      it_should_behave_like 'errors', :destroy

      context 'when account save fails' do
        before { allow(account).to receive(:save).and_raise('Cannot save') }

        it { expect { delete_plan }.to_not change { account.reload.available_modules } }
        it { expect(Stripe::SubscriptionItem).to_not receive(:list) }
        it { expect(sub_item).to_not receive(:delete) }
      end

      context 'when Stripe fails' do
        before do
          allow(Stripe::SubscriptionItem).to receive(:list).and_raise(Stripe::InvalidRequestError)
        end

        it { expect { delete_plan }.to_not change { account.reload.available_modules } }
        it { expect(sub_item).to_not receive(:delete) }
      end
    end
  end
end
