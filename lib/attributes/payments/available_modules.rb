module Payments
  class AvailableModules < Basic
    attribute :data, Array[PlanModule]

    def add(id:, canceled: false)
      data.push(::Payments::PlanModule.new(id: id, canceled: canceled))
    end

    def cancel(plan_id)
      change_canceled_status_to(plan_id, true)
    end

    def reactivate(plan_id)
      change_canceled_status_to(plan_id, false)
    end

    def plan_ids
      data.map(&:id)
    end

    def canceled
      data.select(&:canceled).map(&:id)
    end

    def include?(plan_id)
      data.map(&:id).include?(plan_id)
    end

    delegate :size, to: :data

    private

    def change_canceled_status_to(plan_id, status)
      plan_module = data.find { |plan| plan[:id].eql?(plan_id) }
      return unless plan_module.present?
      plan_module[:canceled] = status
    end
  end
end
