defmodule Helpdesk.Support do
  use Ash.Domain

  resources do
    resource Helpdesk.Support.Ticket do
      define :create_ticket, action: :create
      define :get_ticket_by_id, action: :read, get_by: :id
      define :update_ticket, action: :update
    end
  end
end
