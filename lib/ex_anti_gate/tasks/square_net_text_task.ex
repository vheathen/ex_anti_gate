defmodule ExAntiGate.Tasks.SquareNetTextTask do
  @moduledoc false

  def defaults, do:
   [
      type: "SquareNetTextTask",
      body: nil,
      objectName: nil,
      rowsCount: nil,
      columnsCount: nil
    ]
end
