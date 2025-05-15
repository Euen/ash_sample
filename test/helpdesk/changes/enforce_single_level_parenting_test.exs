defmodule Helpdesk.Changes.EnforceSingleLevelParentingTest do
  use Helpdesk.DataCase, async: true

  alias Helpdesk.Support.Ticket
  alias Helpdesk.Support

  describe "concurrent validation scenarios" do
    test "prevents concurrent parent assignments that would create multi-level hierarchy" do
      # Create three programs
      ticket1 = Support.create_ticket!()
      ticket2 = Support.create_ticket!()
      ticket3 = Support.create_ticket!()

      # Simulate concurrent updates where:
      # - ticket1 tries to set ticket2 as its parent
      # - ticket2 tries to set ticket3 as its parent
      task1 =
        Task.async(fn ->
          Support.update_ticket(ticket1, %{child_of_ticket_id: ticket2.id})
        end)

      task2 =
        Task.async(fn ->
          Support.update_ticket(ticket2, %{child_of_ticket_id: ticket3.id})
        end)

      # Wait for both tasks to complete
      tasks_with_results = Task.await_many([task1, task2])

      # Verify that at least one of the updates failed
      assert Enum.any?(tasks_with_results, fn
               {:error, %Ash.Error.Invalid{}} -> true
               {:ok, _} -> false
             end),
             "Expected at least one concurrent update to fail"

      # Verify that we don't have a multi-level hierarchy
      updated_ticket1 = Support.get_ticket_by_id!(ticket1.id)
      updated_ticket2 = Support.get_ticket_by_id!(ticket2.id)

      # Either ticket1 is a child of ticket2, or ticket2 is a child of ticket3,
      # but not both
      assert (updated_ticket1.child_of_ticket_id == ticket2.id and
                updated_ticket2.child_of_ticket_id == nil) or
               (updated_ticket1.child_of_ticket_id == nil and
                  updated_ticket2.child_of_ticket_id == ticket3.id)
    end

    test "prevents concurrent attempts to set a child program as parent" do
      # Create three programs
      ticket1 = Support.create_ticket!()
      ticket2 = Support.create_ticket!()
      ticket3 = Support.create_ticket!()

      # Simulate concurrent updates where:
      # - program1 tries to set program2 as its parent
      # - program3 tries to set program1 as its parent
      task1 =
        Task.async(fn ->
          Support.update_ticket(ticket1, %{child_of_ticket_id: ticket2.id})
        end)

      task2 =
        Task.async(fn ->
          Support.update_ticket(ticket3, %{child_of_ticket_id: ticket1.id})
        end)

      # Wait for both tasks to complete
      results = Task.await_many([task1, task2])

      # Verify that at least one of the updates failed
      assert Enum.any?(results, fn
               {:error, %Ash.Error.Invalid{}} -> true
               _ -> false
             end),
             "Expected at least one concurrent update to fail"

      # Verify the final state
      updated_ticket1 = Support.get_ticket_by_id!(ticket1.id)
      updated_ticket3 = Support.get_ticket_by_id!(ticket3.id)

      # Either program1 is a child of program2, or program3 is a child of program1,
      # but not both
      assert (updated_ticket1.child_of_ticket_id == ticket2.id and
                updated_ticket3.child_of_ticket_id == nil) or
               (updated_ticket1.child_of_ticket_id == nil and
                  updated_ticket3.child_of_ticket_id == ticket1.id)
    end

    test "allows concurrent parent assignments that don't create multi-level hierarchy" do
      # Create three programs
      ticket1 = Support.create_ticket!()
      ticket2 = Support.create_ticket!()
      ticket3 = Support.create_ticket!()

      # Simulate concurrent updates where:
      # - program1 tries to set program2 as its parent
      # - program3 tries to set program2 as its parent
      task1 =
        Task.async(fn ->
          Support.update_ticket!(ticket1, %{child_of_ticket_id: ticket2.id})
        end)

      task2 =
        Task.async(fn ->
          Support.update_ticket!(ticket3, %{child_of_ticket_id: ticket2.id})
        end)

      # Wait for both tasks to complete
      results = Task.await_many([task1, task2])

      # Verify that both updates succeeded
      assert Enum.all?(results, fn
               %Ticket{} -> true
               _ -> false
             end),
             "Expected both concurrent updates to succeed"

      # Verify the final state
      updated_ticket1 = Support.get_ticket_by_id!(ticket1.id)
      updated_ticket2 = Support.get_ticket_by_id!(ticket2.id)
      updated_ticket3 = Support.get_ticket_by_id!(ticket3.id)

      assert updated_ticket1.child_of_ticket_id == ticket2.id
      assert updated_ticket2.child_of_ticket_id == nil
      assert updated_ticket3.child_of_ticket_id == ticket2.id
    end
  end
end
