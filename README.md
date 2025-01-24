# LiveBulkAsync

[![Hex](https://img.shields.io/hexpm/v/live_bulk_async.svg)](https://hex.pm/packages/live_bulk_async)
[![Hexdocs](https://img.shields.io/badge/-docs-green)](https://hexdocs.pm/live_bulk_async)

LiveBulkAsync is a small library that extends LiveView's async support to work with LiveComponent's `update_many` function.

## Installation

First add `LiveBulkAsync` to your list of dependencies in `mix.exs`:

``` elixir
def deps do
  [
    {:live_bulk_async, "~> 0.1.0"}
  ]
end
```

Now you can directly add support for it in a specific component:

``` elixir
defmodule MyComponent do
  use Phoenix.LiveComponent

  # Add this
  import LiveBulkAsync
  
  ...
end
```

Or you can enable it in all your components by adding it to your `Web` module `live_component` function:

``` elixir
def live_component do
  quote do
    ...
    
    # Add this
    import LiveBulkAsync
  end
end
```

## Usage

Now inside your component `update_many` function, you can use it like this for `start_many_async`:

``` elixir
defmodule MyComponent do
  @moduledoc false

  use Phoenix.LiveComponent

  def update_many(assigns_and_sockets) do
    assigns_and_sockets
    |> Enum.map(fn {assigns, socket} ->
      socket |> assign(assigns) |> assign(loading?: true)
    end)
    |> start_many_async(:content, &load/0)
  end

  def handle_async(:content, {:ok, content}, socket) do
    {:noreply, assign(socket, loading?: false, content: content)}
  end

  def handle_async(:content, {:exit, reason}, socket) do
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div id={@id}>
      <div :if={@loading?}>loading...</div>
      <div :if={not @loading?}>{@content}</div>
    </div>
    """
  end

  defp load! do
    # Load something here
    ["content 1", "content 2"]
  end
end
```

And like this for `assing_many_async`:

``` elixir
defmodule MyComponent do
  @moduledoc false

  use Phoenix.LiveComponent

  def update_many(assigns_and_sockets) do
    assigns_and_sockets
    |> Enum.map(fn {assigns, socket} ->
      socket |> assign(assigns) |> assign(loading?: true)
    end)
    |> assign_many_async(:content, fn -> load!() end)
  end

  def render(assigns) do
    ~H"""
    <div id={@id}>
      <.async_result :let={content} assign={@content}>
      <:loading>Loading...</:loading>
      <:failed :let={reason}><pre>{inspect(reason)}</pre></:failed>
        <div>{content}</div>
      </.async_result>
    </div>
    """
  end

  defp load! do
    # Load something here
    {:ok, %{content: ["content 1", "content 2"]}}
  end
end
```

## Cancel running task

You can also cancel an already running task using `cancel_many_async`, just keep in mind that calling it will cancel the task for all the components that are using it, not only the one you called it from.

You can cancel a task directly from the `update_many` call like this:

``` elixir
def update_many(assigns_and_sockets) do
    assigns_and_sockets
    |> Enum.map(fn {assigns, socket} -> socket end)
    |> cancel_many_async(:content)
end
```

Or from any other callback inside the component that has access to the socket:

``` elixir
def handle_event("cancel_load", _params, socket) do
  socket = cancel_many_async(socket, :content)

  {:noreply, socket}
end
```
