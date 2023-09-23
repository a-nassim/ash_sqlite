defmodule AshSqlite.Calculation do
  @moduledoc false

  require Ecto.Query

  def add_calculations(query, [], _, _), do: {:ok, query}

  def add_calculations(query, calculations, resource, source_binding) do
    query = AshSqlite.DataLayer.default_bindings(query, resource)

    query =
      if query.select do
        query
      else
        Ecto.Query.select_merge(query, %{})
      end

    dynamics =
      Enum.map(calculations, fn {calculation, expression} ->
        type =
          AshSqlite.Types.parameterized_type(
            calculation.type,
            Map.get(calculation, :constraints, [])
          )

        expr =
          AshSqlite.Expr.dynamic_expr(
            query,
            expression,
            query.__ash_bindings__,
            false,
            type
          )

        expr =
          if type do
            Ecto.Query.dynamic(type(^expr, ^type))
          else
            expr
          end

        {calculation.load, calculation.name, expr}
      end)

    {:ok, add_calculation_selects(query, dynamics)}
  end

  defp add_calculation_selects(query, dynamics) do
    {in_calculations, in_body} =
      Enum.split_with(dynamics, fn {load, _name, _dynamic} -> is_nil(load) end)

    calcs =
      in_body
      |> Map.new(fn {load, _, dynamic} ->
        {load, dynamic}
      end)

    calcs =
      if Enum.empty?(in_calculations) do
        calcs
      else
        Map.put(
          calcs,
          :calculations,
          Map.new(in_calculations, fn {_, name, dynamic} ->
            {name, dynamic}
          end)
        )
      end

    Ecto.Query.select_merge(query, ^calcs)
  end
end
