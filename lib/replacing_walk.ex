defmodule ReplacingWalk do
  @moduledoc """
  A hastily constructed replacing walk for use
  with `DeferredConfig`; not
  very performant, but for transforming data
  in options and config, can be convenient.
  """

  require Logger
  
  @doc """
  Recursive replacing walk that uses `recognize` and
  `transform` functions to return a transformed version
  of arbitrary data. 

      iex> ReplacingWalk.walk [1, 2, 3], &(&1 == 2), &(&1 * &1)
      [1,4,3]

      iex> ReplacingWalk.walk( [1, [2, [3, 2]]],
      ...>                        &(&1 == 2), 
      ...>                        &(&1 * &1) 
      ...> )
      [1,[4, [3, 4]]]

  It works for Maps:
  
      iex> ReplacingWalk.walk %{2 => 1, 1 => 2}, &(&1 == 2), &(&1 * &1)
      %{4 => 1, 1 => 4}
  
  Structs in general are considered as leaf nodes; we support 
  structs that implement Enumerable, but **currently we expect
  their `Enumerable` implementation to work like a Map.
  If you feed this an Enumerable struct that doesn't iterate 
  like Map -- ie, doesn't iterate over `{k, v}` -- it will die. 
  (See an example in tests).
  
  We may change that behavior in the future -- either removing
  support for arbitrary Enumerables, or provision another protocol
  that can be implemented to make a data type replacing-walkable.

  Created quickly for
  `:deferred_config`, so it's probably got some holes;
  tests that break it are welcome.
  """
  
  # lists
  def walk(_data = [], _recognize, _transform), do: []
  def walk([item | ls], recognize, transform) do
    item = item |> maybe_transform_leaf(recognize, transform)
    [ walk(item, recognize, transform) |
      walk(ls, recognize, transform) ]
  end

  # structs (enumerable and not; see notes about Enumerable)
  def walk(m = %{ :__struct__ => _ }, recognize, transform) do
    if Enumerable.impl_for(m) do
      m |> walk_map(recognize, transform)
    else
      m |> maybe_transform_leaf(recognize, transform)
    end
  end

  # maps
  def walk(m, recognize, transform) when is_map(m) do
    m |> walk_map(recognize, transform)
  end
  def walk(%{}, _, _), do: %{}

  # kv tuples (very common in config)
  def walk(t = {k,v}, recognize, transform) do
    t = maybe_transform_leaf(t, recognize, transform)
    if is_tuple t do
      {k, v} = t
      {k |> walk(recognize, transform),
       v |> walk(recognize, transform) }
    else t end
  end
  
  # any other data (other tuples; structs; str, atoms, nums..)
  def walk(other, recognize, transform) do
    recognize.(other) |> maybe_do(transform, other)
  end

  # -- impl details for map and maplike enum support
  defp walk_map(m, recognize, transform) do
    
    m = m |> maybe_transform_leaf(recognize, transform)

    # due to above, may not be enumerable any more.
    # also, could be untransformed enumerable, but with
    # non-map-like iteration, which we *can't* detect without trying.
    try do
      Enum.reduce(m, %{}, fn {k, v}, acc ->
        k = recognize.(k) |> maybe_do( transform, k )
        acc |> Map.put(k, walk(v, recognize, transform))
      end)
    catch _ ->
        Logger.error("replacing walk: reduce failed for: #{inspect m}")
        m
    end
  end

  defp maybe_transform_leaf(o, recognize, transform) do
    recognize.(o) |> maybe_do(transform, o)
  end
  defp maybe_do(_should_i = true, op, item), do: op.(item)
  defp maybe_do(_shouldnt, _op, item),       do: item

end
