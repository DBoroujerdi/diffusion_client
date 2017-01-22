require Logger

require Monad.Error, as: Error

import Error

defmodule Diffusion.Websocket do

  @spec send(pid, binary) :: :ok

  def send(connection, data) do
    Logger.info "Sending #{data}"
    :gun.ws_send(connection, {:binary, data})
  end


  @spec close(pid) :: :ok

  def close(connection) do
    :gun.close(connection)
  end


  @spec open_websocket(map) :: {:ok, pid} | {:error, any}

  def open_websocket(config) do
    case open_connection(config) do
      {:ok, connection} ->
        case wait_up(connection, config) do
          {:error, _} = error ->
            close(connection)
            error
          connection -> connection
        end
      error -> error
    end

    # case open_connection(config) do
    #   {:ok, connection} ->
    #     with {:ok, _} <- wait_up(connection, config)
    #       do {:ok, connection}
    #       else
    #         error ->
    #           close(connection)
    #           error
    #     end
    #   error -> error
    # end
  end


  ##
  ## private
  ##

  defp wait_up(connection, config) do
    Error.p do
      {:ok, connection}
      |> await_up(config)
      |> upgrade_to_ws(config)
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



  defp open_connection(%{host: host, port: port}) do
    :gun.open(String.to_charlist(host), port)
  end


  defp await_up(connection, %{timeout: timeout}) do
    case :gun.await_up(connection, timeout) do
      {:ok, _} -> {:ok, connection}
      error -> error
    end
  end
end
