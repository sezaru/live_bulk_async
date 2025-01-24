defmodule LiveBulkAsync.Channel do
  @moduledoc false

  @prefix :phoenix

  def report_async_result(kind, key, results_cids_refs) when kind in [:start, :assign] do
    Enum.each(results_cids_refs, fn {result, cid, ref} ->
      send(ref, {@prefix, :async_result, {kind, {ref, cid, key, result}}})
    end)
  end
end
