# frozen_string_literal: true

module Employees
  class Index
    include AppDependencies[account_model: "models.account"]

    def call(status: nil)
      account_model.current.employees.public_send(scope(status))
    end

    private

    def scope(status)
      case status
      when "active" then "active_at_date"
      when "inactive" then "inactive_at_date"
      else "all"
      end
    end
  end
end
