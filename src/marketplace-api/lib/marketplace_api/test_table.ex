defmodule MarketplaceApi.TestTable do
  use Ecto.Schema
  import Ecto.Changeset

  schema "test_table" do
    field :name, :string
    field :message, :string
    timestamps()
  end

  def changeset(test_table, attrs) do
    test_table
    |> cast(attrs, [:name, :message])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 255)
  end
end
