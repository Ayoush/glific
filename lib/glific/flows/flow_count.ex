defmodule Glific.Flows.FlowCount do
  @moduledoc """
  The flow count object
  """
  use Ecto.Schema
  import Ecto.Changeset

  import Ecto.Query, warn: false
  alias __MODULE__

  alias Glific.{
    Flows.Flow,
    Partners.Organization,
    Repo
  }

  @required_fields [:uuid, :flow_id, :type, :flow_uuid, :organization_id]
  @optional_fields [:destination_uuid, :recent_messages, :count]

  @type t() :: %__MODULE__{
          __meta__: Ecto.Schema.Metadata.t(),
          id: non_neg_integer | nil,
          uuid: Ecto.UUID.t() | nil,
          flow_id: non_neg_integer | nil,
          flow_uuid: Ecto.UUID.t() | nil,
          flow: Flow.t() | Ecto.Association.NotLoaded.t() | nil,
          organization_id: non_neg_integer | nil,
          organization: Organization.t() | Ecto.Association.NotLoaded.t() | nil,
          type: String.t() | nil,
          count: integer() | nil,
          destination_uuid: Ecto.UUID.t() | nil,
          recent_messages: [map()] | nil,
          inserted_at: :utc_datetime | nil,
          updated_at: :utc_datetime | nil
        }

  schema "flow_counts" do
    field :uuid, Ecto.UUID
    field :flow_uuid, Ecto.UUID
    belongs_to :flow, Flow
    belongs_to :organization, Organization
    field :type, :string
    field :count, :integer
    field :destination_uuid, Ecto.UUID
    field :recent_messages, {:array, :map}, default: []

    timestamps(type: :utc_datetime)
  end

  @doc """
  Standard changeset pattern we use for all data types
  """
  @spec changeset(FlowCount.t(), map()) :: Ecto.Changeset.t()
  def changeset(flow_revision, attrs) do
    flow_revision
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end

  @doc """
  Get a list of flow count
  """
  @spec get_flow_count_list(Ecto.UUID.t()) :: :error | list()
  def get_flow_count_list(nil), do: []

  def get_flow_count_list(flow_uuid) do
    FlowCount
    |> where([fc], fc.flow_uuid == ^flow_uuid)
    |> Repo.all()
  end

  @doc """
  Create flow count
  """
  @spec create_flow_count(map()) :: {:ok, FlowCount.t()} | {:error, Ecto.Changeset.t()}
  def create_flow_count(attrs) do
    %FlowCount{}
    |> FlowCount.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Update flow count
  """
  @spec update_flow_count(FlowCount.t(), map()) ::
          {:ok, FlowCount.t()} | {:error, Ecto.Changeset.t()}
  def update_flow_count(%FlowCount{} = flow_count, attrs) do
    flow_count
    |> FlowCount.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Upsert flow count
  """
  @spec upsert_flow_count(map()) :: :error | FlowCount.t()
  def upsert_flow_count(%{flow_uuid: nil} = _attrs), do: :error

  def upsert_flow_count(attrs) do
    case Repo.fetch_by(FlowCount, %{uuid: attrs.uuid}) do
      {:ok, flowcount} ->
        recent_message = update_recent_messages(flowcount, attrs)

        update_flow_count(
          flowcount,
          Map.merge(attrs, %{count: flowcount.count + 1, recent_messages: recent_message})
        )

      {:error, _} ->
        attrs =
          if Map.has_key?(attrs, :recent_message),
            do: Map.merge(attrs, %{recent_messages: [attrs.recent_message]}),
            else: attrs

        create_flow_count(attrs)
    end
  end

  @spec update_recent_messages(FlowCount.t(), map()) :: [any()]
  defp update_recent_messages(flow_count, %{recent_message: recent_message})
       when recent_message != %{} do
    [recent_message | flow_count.recent_messages]
    |> Enum.take(5)
  end

  defp update_recent_messages(_, _), do: []
end
