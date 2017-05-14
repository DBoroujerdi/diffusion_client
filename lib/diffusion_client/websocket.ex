require Logger

defmodule Diffusion.Websocket do

  @spec send(pid, binary) :: :ok

  def send(connection, data) do
    Logger.debug "Sending #{data}"
    :gun.ws_send(connection, {:binary, data})
  end


  @spec close(pid) :: :ok

  def close(connection) do
    :gun.close(connection)
  end


  @spec open(map) :: {:ok, pid} | {:error, any}

  def open(config) do
    case open_connection(config) do
      {:ok, connection} ->
        with {:ok, _} <- wait_up(connection, config)
          do {:ok, connection}
          else
            error ->
              close(connection)
              error
        end
      error -> error
    end
  end


  ##
  ## private
  ##

  defp wait_up(connection, config) do
    with {:ok, connection} <- await_up(connection, config),
	 {:ok, connection} <-  upgrade_to_ws(connection, config)
      do
      {:ok, connection}
    end
  end


  defp upgrade_to_ws(connection, %{path: path, headers: headers}) do
    _ = :gun.ws_upgrade(connection, path, headers)

    receive do
      {:gun_ws_upgrade, ^connection, :ok, _} ->
        {:ok, connection}
      other ->
        {:error, {:unexpected_message, other}}
    end
  end

  defp upgrade_to_ws(connection, config) do
    upgrade_to_ws(connection, Map.put(config, :headers, []))
  end


  defp open_connection(%{host: host, port: port}), do:
    :gun.open(String.to_charlist(host), port)
  defp open_connection(%{host: host, port: port, transport: :ssl}) do
    :gun.open(String.to_charlist(host), port, %{transport: :ssl})
  end


  defp await_up(connection, %{timeout: timeout}) do
    case :gun.await_up(connection, timeout) do
      {:ok, _} -> {:ok, connection}
      error -> error
    end
  end
end
