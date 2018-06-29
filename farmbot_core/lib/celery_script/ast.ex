defmodule Farmbot.CeleryScript.AST do
  @moduledoc """
  Handy functions for turning various data types into Farbot Celery Script
  Ast nodes.
  """

  alias Farmbot.CeleryScript.AST

  @typedoc "Arguments to a Node."
  @type args :: map

  @typedoc "Body of a Node."
  @type body :: [t]

  @typedoc "Kind of a Node."
  @type kind :: atom

  @typedoc "AST node."
  @type t :: %__MODULE__{
    kind: kind,
    args: args,
    body: body,
    comment: String.t
  }

  @keys [:kind, :args, :body, :comment] ++ ["kind", "args", "body", "comment"]

  # AST struct.
  defstruct [:kind, :args, :body, :comment]

  @doc "Build an AST with each individual field."
  def new(kind, args, body, comment) do

  end

  @doc "Build an AST from an existing map."
  def new(%{} = map) do
    Map.take(map, @keys)
    |> Enum.map(fn({key, v}) ->
      {String.to_atom(key), }
    end)
    |> Enum.map(fn({key, value}) ->
    end)
    |> fn(data) -> struct(AST, data) end.()
  end

  def is_celery?(%AST{}), do: true
  def is_celery?(%{"kind" => _, "args" => _}), do: true
  def is_celery?(%{kind: _, args: _}), do: true
  def is_celery(_), do: false
end
