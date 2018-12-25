defmodule Priv do
  @moduledoc """
  A macro for converting all private functions into public functions that exist under
  __MODULE__.Private
  """

  defmacro __using__(_env) do
    quote do
      Module.register_attribute(__MODULE__, :replace_register, accumulate: true)
      @on_definition Priv
      @before_compile Priv
    end
  end

  defmacro __before_compile__(env) do
    replace_funcs = Module.get_attribute(env.module, :replace_register)

    require_declarations =
      Enum.filter(env.requires, fn
        __MODULE__ ->
          false

        _other ->
          true
      end)
      |> Enum.map(fn require_name ->
        "require #{require_name}"
      end)

    Module.put_attribute(env.module, :replace_ran, true)

    {private_functions, defpdelegates, _uniq_functions, module_attributes, aliases} =
      Enum.reduce(replace_funcs, {[], [], [], [], []}, fn {name, body, args, guards, module,
                                                           tuple},
                                                          {private_functions, defpdelegates,
                                                           uniq_functions, module_attributes,
                                                           aliases} ->
        :elixir_def.take_definition(module, tuple)

        {_, {module_attributes_for_function, alias_uses}} =
          Macro.prewalk(body, {[], []}, fn
            {:@, _, [{name, _, nil}]} = value, {module_attributes, aliases} ->
              {value, {[name | module_attributes], aliases}}

            {:__aliases__, _, alias_path} = value, {module_attributes, aliases} ->
              {value, {module_attributes, [alias_path | aliases]}}

            value, {module_attributes, aliases} ->
              {value, {module_attributes, aliases}}
          end)

        new_aliases =
          Enum.reduce(alias_uses, [], fn alias_name, acc ->
            [deepest_module | _] = Enum.reverse(alias_name)
            module_name = :"Elixir.#{Atom.to_string(deepest_module)}"

            env.aliases
            |> Enum.find(fn
              {^module_name, _full_module_path} ->
                true

              _other ->
                false
            end)
            |> case do
              {_alias_name, alias_path} ->
                [{List.last(alias_name), alias_path} | acc]

              _other ->
                acc
            end
          end)

        private_function =
          if Enum.any?(guards) do
            quote do
              def unquote(name)(unquote_splicing(args)) when unquote_splicing(guards),
                  unquote(body)
            end
          else
            quote do
              def unquote(name)(unquote_splicing(args)), unquote(body)
            end
          end

        function_signature = {name, Enum.count(args)}

        if function_signature in uniq_functions do
          {[private_function | private_functions], defpdelegates, uniq_functions,
           module_attributes_for_function ++ module_attributes, new_aliases ++ aliases}
        else
          defpdelegate =
            quote do
              defp unquote(name)(unquote_splicing(safe_args(args))),
                do: apply(__MODULE__.Private, unquote(name), unquote(safe_args(args)))
            end

          {[private_function | private_functions], [defpdelegate | defpdelegates],
           [function_signature | uniq_functions],
           module_attributes_for_function ++ module_attributes, new_aliases ++ aliases}
        end
      end)

    module_attribute_declarations =
      module_attributes
      |> Enum.uniq()
      |> Enum.map(fn attribute_name ->
        "@#{attribute_name} #{Module.get_attribute(env.module, attribute_name)}"
      end)

    alias_declarations =
      aliases
      |> Enum.uniq()
      |> Enum.map(fn {alias_name, alias_path} ->
        "alias #{alias_path}, as: #{alias_name}"
      end)

    module = """
    defmodule #{env.module}.Private do
    #{Enum.join(require_declarations, "\n")}
    #{Enum.join(alias_declarations, "\n")}
    #{Enum.join(module_attribute_declarations, "\n")}

    #{Enum.map(private_functions, &(Macro.to_string(&1) <> "\n\n"))}
    end
    """

    Code.compile_string(module)

    quote do
      unquote(defpdelegates)
    end
  end

  defp safe_args(args) do
    args
    |> Enum.with_index()
    |> Enum.map(fn {_arg, index} ->
      {String.to_atom("x_#{index}"), [], nil}
    end)
  end

  def __on_definition__(env, :defp, name, args, guards, body) do
    if Module.get_attribute(env.module, :replace_ran) != true do
      tuple = {name, length(args)}

      Module.put_attribute(
        env.module,
        :replace_register,
        {name, body, args, guards, env.module, tuple}
      )
    end
  end

  def __on_definition__(_env, _other, _name, _args, _guards, _body) do
  end
end
