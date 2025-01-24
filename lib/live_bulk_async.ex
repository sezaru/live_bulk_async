defmodule LiveBulkAsync do
  @moduledoc """
  Documentation for `LiveBulkAsync`.
  """

  alias LiveBulkAsync.Channel

  alias Phoenix.LiveView.{AsyncResult, Socket, Async}

  def start_many_async(sockets, key, func, opts \\ [])
  def start_many_async([], _key, _func, _opts), do: []

  def start_many_async(sockets, key, func, opts),
    do: run_async_task(sockets, key, func, :start, opts)

  def assign_many_async(sockets, key_or_keys, func, opts \\ [])

  def assign_many_async(sockets, key_or_keys, func, opts)
      when (is_atom(key_or_keys) or is_list(key_or_keys)) and is_function(func, 0) do
    keys = List.wrap(key_or_keys)

    wrapped_func = fn ->
      case func.() do
        {:ok, %{} = assigns} ->
          if Enum.find(keys, &(not is_map_key(assigns, &1))) do
            raise ArgumentError, """
            expected assign_async to return map of assigns for all keys
            in #{inspect(keys)}, but got: #{inspect(assigns)}
            """
          else
            {:ok, assigns}
          end

        {:error, reason} ->
          {:error, reason}

        other ->
          raise ArgumentError, """
          expected assign_async to return {:ok, map} of
          assigns for #{inspect(keys)} or {:error, reason}, got: #{inspect(other)}
          """
      end
    end

    maybe_reset = fn sockets ->
      reset? = Keyword.get(opts, :reset, false)

      Enum.map(sockets, fn socket ->
        new_assigns =
          Enum.map(keys, fn key ->
            reset? = if is_list(reset?), do: key in reset?, else: reset?

            case {reset?, socket.assigns} do
              {false, %{^key => %AsyncResult{ok?: true} = existing}} ->
                {key, AsyncResult.loading(existing, keys)}

              _ ->
                {key, AsyncResult.loading(keys)}
            end
          end)

        Phoenix.Component.assign(socket, new_assigns)
      end)
    end

    sockets
    |> maybe_reset.()
    |> run_async_task(keys, wrapped_func, :assign, opts)
  end

  def cancel_many_async(sockets_or_socket, key, reason \\ {:shutdown, :cancel})

  def cancel_many_async(sockets, key, reason) when is_list(sockets) do
    Enum.map(sockets, fn socket -> cancel_many_async(socket, key, reason) end)
  end

  def cancel_many_async(%Socket{} = socket, key, reason) do
    case get_private_async(socket, key) do
      {_ref, pid, _kind} when is_pid(pid) ->
        Process.unlink(pid)
        Process.exit(pid, reason)

        socket

      nil ->
        socket
    end
  end

  defp run_async_task(sockets, key, func, kind, opts) do
    if sockets |> hd() |> Phoenix.LiveView.connected?() do
      lv_pid = self()

      cids = Enum.map(sockets, fn socket -> cid(socket) end)

      {:ok, pid} =
        if supervisor = Keyword.get(opts, :supervisor) do
          Task.Supervisor.start_child(supervisor, fn ->
            Process.link(lv_pid)

            do_many_async(lv_pid, cids, key, func, kind)
          end)
        else
          Task.start_link(fn -> do_many_async(lv_pid, cids, key, func, kind) end)
        end

      refs =
        Enum.map(cids, fn cid ->
          :erlang.monitor(:process, pid, alias: :reply_demonitor, tag: {Async, key, cid, :start})
        end)

      send(pid, {:context, refs})

      sockets
      |> Enum.zip(refs)
      |> Enum.map(fn {socket, ref} ->
        update_private_async(socket, &Map.put(&1, key, {ref, pid, :start}))
      end)
    else
      sockets
    end
  end

  defp do_many_async(lv_pid, cids, key, func, kind) do
    total_cids = Enum.count(cids)

    receive do
      {:context, refs} ->
        try do
          results = func.() |> convert_results(total_cids, kind)

          results_cids_refs = Enum.zip([results, cids, refs])

          Channel.report_async_result(kind, key, results_cids_refs)
        catch
          catch_kind, reason ->
            Process.unlink(lv_pid)

            results = catch_kind |> to_exit(reason, __STACKTRACE__) |> List.duplicate(total_cids)
            results_cids_refs = Enum.zip([results, cids, refs])

            Channel.report_async_result(kind, key, results_cids_refs)

            :erlang.raise(catch_kind, reason, __STACKTRACE__)
        end
    end
  end

  defp convert_results(results, _total, :start), do: Enum.map(results, &{:ok, &1})

  defp convert_results({:ok, results}, _total, :assign) do
    keys = Map.keys(results)
    values = Map.values(results)

    values
    |> Enum.zip()
    |> Enum.map(fn values ->
      values = Tuple.to_list(values)

      {:ok, {:ok, keys |> Enum.zip(values) |> Map.new()}}
    end)
  end

  defp convert_results({:error, reason}, total, :assign) do
    {:error, reason} |> List.duplicate(total) |> Enum.map(&{:ok, &1})
  end

  defp update_private_async(%{private: private} = socket, func) do
    existing = Map.get(private, :live_async, %{})

    %{socket | private: Map.put(private, :live_async, func.(existing))}
  end

  defp get_private_async(%Socket{} = socket, key) do
    socket.private[:live_async][key]
  end

  defp to_exit(:throw, reason, stack), do: {:exit, {{:nocatch, reason}, stack}}
  defp to_exit(:error, reason, stack), do: {:exit, {reason, stack}}
  defp to_exit(:exit, reason, _stack), do: {:exit, reason}

  defp cid(%Socket{} = socket) do
    if myself = socket.assigns[:myself], do: myself.cid
  end
end
