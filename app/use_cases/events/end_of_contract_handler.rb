module Events
  module EndOfContractHandler
    # NOTE: Find and destroy first end of contract balance before eoc_event's effective_at
    def destroy_eoc_balance
      find_and_destroy_eoc_balance.call(
        employee: employee, eoc_date: eoc_event.effective_at
      )
    end

    # NOTE: Find first end of contract event after new work contract event's effective_at
    def eoc_event
      @eoc_event ||= find_first_eoc_event_after.call(effective_at: effective_at, employee: employee)
    end

    # NOTE: Create new end of contract balance with new effective_at date
    def recreate_eoc_balance
      create_eoc_balance.call(
        employee: employee,
        contract_end_date: eoc_event.effective_at,
        eoc_event_id: eoc_event.id
      )
    end
  end
end
