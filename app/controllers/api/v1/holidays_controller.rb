module API
  module V1
    class HolidaysController < JSONAPI::ResourceController
      include API::V1::ExceptionsHandler
      include API::V1::Exceptions

      before_action :check_holiday_policy, only: [:create, :update]

      private

      def check_holiday_policy
        check_if_policy_exist && check_if_current_user_authorized if holiday_policy
      end

      def set_holiday_policy
        attributes = params['data']['attributes']
        attributes['holiday-policy-id'] if attributes
      end

      def check_if_policy_exist
        HolidayPolicy.find(holiday_policy)
      rescue => e
        handle_exceptions(e)
      end

      def check_if_current_user_authorized
        unless user_holiday_policies.include?(holiday_policy)
          fail Forbidden.new(holiday_policy), 'Holiday policy forbidden'
        end
      rescue => e
        handle_exceptions(e)
      end

      def holiday_policy
        @holiday_policy ||= set_holiday_policy
      end

      def user_holiday_policies
        @user_holiday_policies ||= HolidayPolicy.where(account_id: Account.current.id).pluck(:id)
      end
    end
  end
end
