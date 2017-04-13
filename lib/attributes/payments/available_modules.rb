module Payments
  class AvailableModules < ::BasicAttribute
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

    def delete(plan_id)
      data.delete(find_plan_module(plan_id))
    end

    def delete_all
      self.data = []
    end

    def clean
      self.data = data.reject(&:canceled)
    end

    def all
      data.map(&:id)
    end

    def canceled
      data.select(&:canceled).map(&:id)
    end

    def actives
      data.reject(&:canceled).map(&:id)
    end

    def include?(plan_id)
      data.map(&:id).include?(plan_id)
    end

    delegate :size, to: :data

    private

    def change_canceled_status_to(plan_id, status)
      plan_module = find_plan_module(plan_id)
      return unless plan_module.present?
      plan_module[:canceled] = status
    end

    def find_plan_module(plan_id)
      data.find { |plan| plan[:id].eql?(plan_id) }
    end
  end
end
