defmodule Ham do defstruct( a: 1 ) end
defmodule Spam do defstruct( a: 1, b: 2 ) end
defimpl Enumerable, for: Spam do
  def count(_),     do: {:error, __MODULE__}  # default reduce-based
  def member?(_,_), do: {:error, __MODULE__}  # default reduce-based
  def reduce(%{a: a, b: b}, {_, acc}, fun) do
    {:cont, acc} = fun.({:a, a}, acc)
    {:cont, acc} = fun.({:b, b}, acc)
    {:done, acc}
  end
end

defmodule EnvTest do
  use ExUnit.Case
  doctest DeferredConfig
  alias ReplacingWalk, as: RW

  test "basic " do
    data     = [:a, :b, :c]
    expected = [:balls, :b, :c]
    actual = data
    |> RW.walk( &recognize_atom_a/1, &transform_to_balls/1 )
    assert expected == actual
  end

  test "maps" do
    data     = %{ :a => 1, :b => 2, :a => :a }
    expected = %{ :balls => 1, :b => 2, :balls => :balls}  
    actual = data
    |> RW.walk(&recognize_atom_a/1, &transform_to_balls/1) 
    assert expected == actual
  end
  
  test "map - kitchen sink" do
    assert example_data().kitchen_sink_map_a_to_balls ==
      example_data().kitchen_sink_map_a
      |> RW.walk( &recognize_atom_a/1, &transform_to_balls/1)
  end

  test "structs won't change if they're not enumerable" do
    data = %Ham{ a: 2}
    expected = %Ham{ a: 2}
    actual = data
    |> RW.walk(&recognize_atom_a/1, &transform_to_balls/1)
    assert expected == actual
  end

  test "enumerable types are ok tho" do
    recognize = fn i -> i == 3 end
    data = %Spam{ a: 2, b: 3}
    assert Enumerable.impl_for(data) == Enumerable.Spam
    expected = %{ a: 2, b: :balls}
    actual = data
    |> RW.walk(recognize, &transform_to_balls/1)
    assert expected == actual
  end

  def recognize_atom_a(:a), do: true
  def recognize_atom_a(_),  do: false
  def transform_to_balls(_), do: :balls

  def example_data do
    %{kitchen_sink_map_a:
      %{
        :a => 1,   # replaceable key
        :b => 2,
        :c => [
          [ :a, {:a, 3} ],  # list
          [ a: 2, a: 3 ]    # kvlist
        ],
        :d => :a   # replaceable value
      },
      kitchen_sink_map_a_to_balls:
      %{
        :balls => 1,   # replaceable key
        :b => 2,
        :c => [
          [ :balls, {:balls, 3} ],  # tuples NOT replaced yet
          [ balls: 2, balls: 3 ]    # kvlist NOT replaced yet
        ],
        :d => :balls   # replaceable value
      }
    }
  end
end


