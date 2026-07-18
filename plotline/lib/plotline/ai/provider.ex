defmodule Plotline.AI.Provider do
  @moduledoc false

  @callback generate(system_instruction :: String.t(), user_message :: String.t()) ::
              {:ok, String.t()} | {:error, term()}
end
