defmodule HelloWorld do
  use Plug.Router
  import Ecto.Query
  alias MarketplaceApi.Repo
  alias MarketplaceApi.TestTable

  plug Plug.Logger
  plug :match
  plug :dispatch

  get "/" do
    send_resp(conn, 200, "<h1>Hello World from Elixir!</h1><p>Rukmer Commons Deployment Test</p><p>Database: Ecto + Phoenix Ready 🚀</p>")
  end

  get "/health" do
    send_resp(conn, 200, ~s({"status": "healthy", "service": "rukmer-app", "database": "ecto-ready"}))
  end

  # Database connection test using Ecto
  get "/db/test" do
    case Repo.query("SELECT version()", []) do
      {:ok, %{rows: [[version]]}} ->
        response = %{
          "status" => "connected",
          "database_version" => version,
          "connection_pool" => "ecto"
        }
        send_resp(conn, 200, Jason.encode!(response))

      {:error, reason} ->
        response = %{"status" => "error", "reason" => inspect(reason)}
        send_resp(conn, 500, Jason.encode!(response))
    end
  end

  # Create test table using Ecto migration
  post "/db/create-test-table" do
    try do
      # Create table using raw SQL (in production, use proper migrations)
      Repo.query!("""
        CREATE TABLE IF NOT EXISTS test_table (
          id SERIAL PRIMARY KEY,
          name VARCHAR(255) NOT NULL,
          message TEXT,
          inserted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      """)

      # Insert test data using Ecto
      changeset = TestTable.changeset(%TestTable{}, %{
        name: "drone_test",
        message: "Ecto connection test from EC2 at #{DateTime.utc_now()}"
      })

      case Repo.insert(changeset) do
        {:ok, test_record} ->
          response = %{
            "status" => "success",
            "message" => "Test table created and data inserted using Ecto",
            "record" => %{
              "id" => test_record.id,
              "name" => test_record.name,
              "message" => test_record.message
            }
          }
          send_resp(conn, 200, Jason.encode!(response))

        {:error, changeset} ->
          errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
            Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
              opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
            end)
          end)

          response = %{"status" => "error", "errors" => errors}
          send_resp(conn, 400, Jason.encode!(response))
      end
    rescue
      e ->
        response = %{"status" => "error", "reason" => Exception.message(e)}
        send_resp(conn, 500, Jason.encode!(response))
    end
  end

  # Get test table data using Ecto queries
  get "/db/test-table" do
    try do
      records =
        TestTable
        |> order_by(desc: :inserted_at)
        |> limit(10)
        |> Repo.all()

      response = %{
        "status" => "success",
        "count" => length(records),
        "records" => Enum.map(records, fn record ->
          %{
            "id" => record.id,
            "name" => record.name,
            "message" => record.message,
            "inserted_at" => record.inserted_at
          }
        end)
      }
      send_resp(conn, 200, Jason.encode!(response))
    rescue
      e ->
        response = %{"status" => "error", "reason" => Exception.message(e)}
        send_resp(conn, 500, Jason.encode!(response))
    end
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end
end
