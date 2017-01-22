
defmodule Diffusion.TopicMappings do
  alias Diffusion.TopicMappings

  @type topic_alias :: String.t
  @type topic :: String.t
  @type handler :: module

  @type key_type :: :alias | :topic

  @opaque t :: %TopicMappings{alias_map: map, handler_map: map}

  defstruct alias_map: %{}, handler_map: %{}


  @spec new :: TopicMappings.t

  def new do
    %TopicMappings{}
  end


  @doc """
  Get handler keyed by either topic name or topic alias.

  Topic.get(topics, :topic, "topic_name")

  Topic.get(topics, :alias, "!fot")
  """

  @spec get(TopicMappings.t, :key_type, topic_alias) :: handler | nil

  def get(topics, :alias, topic_alias) do
    case Map.get(topics.alias_map, topic_alias) do
      nil -> nil
      topic ->
        Map.get(topics.handler_map, topic, nil)
    end
  end

  def get(topics, :topic, topic) do
    Map.get(topics.handler_map, topic)
  end



  @doc """
  Add a topic to handler mapping entry.
  """

  @spec add_topic(TopicMappings.t, topic, handler) :: TopicMappings.t

  def add_topic(topics, topic, handler) do
    updated_handler_map = Map.put(topics.handler_map, topic, handler)
    Map.put(topics, :handler_map, updated_handler_map)
  end


  @doc """
  Add an alias for a topic already in the structure so that entries
  can be looked up via an alias, like a secondary key.

  Returns {:error, {:no_topic, topic_name}} when the structure does not
  already contain an entry for the topic topic_name.
  """

  @spec add_topic_alias(Topics.t, topic_alias, topic) :: TopicMappings.t

  def add_topic_alias(topics, topic_alias, topic) do
    case get(topics, :topic, topic) do
      nil ->
        {:error, {:no_topic, topic}}
      _ ->
        updated_alias_map = Map.put(topics.alias_map, topic_alias, topic)
        Map.put(topics, :alias_map, updated_alias_map)
    end
  end


  # todo: implement a protocol so that this structure can be to stringed
end
