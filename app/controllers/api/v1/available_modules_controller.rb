module API
  module V1
    class AvailableModulesController < API::ApplicationController
      include AvailableModulesSchemas

      before_action { authorize!(action_name.to_sym, :available_modules) }

      def index
        render_resource(stripe_plans + internal_plans)
      end

      def update
        verified_dry_params(dry_validation_schema) do |attributes|
          if available_modules.include?(params[:id])
            update_available_modules(attributes[:id], attributes[:free])
          else
            available_modules.add(id: params[:id], free: true)
          end
          Account.current.save!
          render_no_content
        end
      end

      private

      def update_available_modules(plan_id, free)
        if internal_plans.map(&:id).include?(plan_id) && !free
          available_modules.delete(plan_id)
        else
          plan = available_modules.find(plan_id)
          plan.free = free
        end
      end

      def internal_plans
        YAML.load(File.read('config/internal_available_modules.yml')).map do |internal_module|
          internal_module = OpenStruct.new(internal_module)
          enabled_and_free_fields_for(internal_module)
        end
      end

      def stripe_plans
        Stripe::Plan.list.select do |plan|
          next if plan.id.eql?('free-plan')
          enabled_and_free_fields_for(plan)
        end
      end

      def enabled_and_free_fields_for(plan)
        plan.enabled = enabled_plans.include?(plan.id)
        plan.free = free_plans.include?(plan.id)
        plan
      end

      def enabled_plans
        @enabled_plans ||= Account.current.available_modules.all
      end

      def free_plans
        @free_plans ||= Account.current.available_modules.free
      end

      def resource_representer
        ::Api::V1::AvailableModuleRepresenter
      end

      def available_modules
        Account.current.available_modules
      end
    end
  end
end
