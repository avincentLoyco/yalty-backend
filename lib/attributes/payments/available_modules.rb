module Payments
  class AvailableModules < ::SimpleAttribute
    attribute :data, Array[PlanModule]

    def add(id:, canceled: false, free: false)
      data.push(::Payments::PlanModule.new(id: id, canceled: canceled, free: free))
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

    def delete_paid
      data.select!(&:free)
    end

    def clean
      data.select! { |plan| plan.free || !plan.canceled }
    end

    def all
      data.map(&:id)
    end

    def canceled
      data.select { |plan| plan.canceled && !plan.free }.map(&:id)
    end

    def actives
      data.select { |plan| plan.free || !plan.canceled }.map(&:id)
    end

    def free
      data.select(&:free).map(&:id)
    end

    def canceled_or_free
      canceled + free
    end

    def include?(plan_id)
      data.map(&:id).include?(plan_id)
    end

    def find(plan_id)
      data.find { |plan| plan.id.eql?(plan_id) }
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
