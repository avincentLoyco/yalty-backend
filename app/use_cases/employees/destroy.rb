# frozen_string_literal: true

module Employees
  class Destroy
    def call(employee)
      Employee.transaction do
        delete_intercom_user(employee.user.id) unless employee.user.nil?
        employee.destroy!
      end
    end

    private

    def delete_intercom_user(user_id)
      user = intercom_client.users.find(user_id: user_id)
      intercom_client.users.delete(user)
    end

    def intercom_client
      @intercom_client ||= IntercomService.new.client
    end
  end
end
