defmodule Helpdesk.Changes.EnforceSingleLevelParenting do
  use Ash.Resource.Change

  @impl true
  def change(changeset, attributes, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      with {:ok, parent_id} <- get_parent_id(changeset, attributes[:parent_key]),
           {:ok, parent} <- Ash.get(changeset.resource, parent_id) do
        cond do
          a_child?(parent, attributes[:parent_key]) ->
            # Validate that the referenced parent (i.e. child_of_program_id) is not itself a child.
            Ash.Changeset.add_error(changeset, "Cannot assign a parent that is already a child")

          a_parent?(changeset, attributes[:children_key]) ->
            # Validate that the record being updated is not itself a parent.
            Ash.Changeset.add_error(
              changeset,
              "Cannot assign this entity as child because it is already a parent."
            )

          true ->
            # If I add an sleep here, to ensure the seccond task reach this point before the first task finishes.
            # The test should fail because both records should be updated based on the same data obtained by the `Ash.get`
            # with no lock. But this is not happening.
            # :timer.sleep(100)
            Ash.Changeset.force_change_attribute(changeset, attributes[:parent_key], parent_id)
        end
      else
        _ ->
          changeset
      end
    end)
  end

  defp get_parent_id(changeset, attribute) do
    case Ash.Changeset.get_attribute(changeset, attribute) do
      nil -> {:error, nil}
      parent_id -> {:ok, parent_id}
    end
  end

  defp a_child?(parent, attribute) do
    case Map.get(parent, attribute) do
      nil -> false
      _ -> true
    end
  end

  defp a_parent?(changeset, children_field) when changeset.action_type == :update do
    id = Ash.Changeset.get_data(changeset, :id)

    case Ash.get(changeset.resource, id, load: children_field) do
      {:error, _reason} -> false
      {:ok, record} -> Map.get(record, children_field) != []
    end
  end

  defp a_parent?(changeset, _children_field) when changeset.action_type == :create do
    false
  end
end
