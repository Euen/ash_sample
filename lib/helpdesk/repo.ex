defmodule Helpdesk.Repo do
  use AshPostgres.Repo,
    otp_app: :helpdesk
    # adapter: Ecto.Adapters.Postgres
end
