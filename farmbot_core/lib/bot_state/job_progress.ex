defmodule Farmbot.BotState.JobProgress do
  @moduledoc "Interface for job progress."

  @typedoc "Unit of the job."
  @type unit :: :percent | :bytes
  @typedoc "Status of the job."
  @type status :: :working | :complete | :error

  defmodule Percent do
    @moduledoc "Percent job."
    defstruct [status: :working, percent: 0, unit: :percent]

    defimpl Inspect, for: __MODULE__ do
      def inspect(%{percent: percent}, _) do
        "#Percent<#{percent}>"
      end
    end
    @type t :: %__MODULE__{
      status:  Farmbot.BotState.JobProgress.status,
      percent: integer,
      unit:    :percent
    }
  end

  defmodule Bytes do
    @moduledoc "Bytes job."
    defstruct [status: :working, bytes: 0, unit: :bytes]

    defimpl Inspect, for: __MODULE__ do
      def inspect(%{bytes: bytes}, _) do
        "#bytes<#{bytes}>"
      end
    end

    @type t :: %__MODULE__{
      status: Farmbot.BotState.JobProgress.status,
      bytes:  integer,
      unit:   :bytes
    }
  end

  @type t :: Bytes.t | Percent.t
end
