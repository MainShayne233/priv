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


    quote do
      unquote(env)
    end

    Module.put_attribute(env.module, :replace_ran, true)

    {private_functions, defpdelegates, uniq_functions} =
      Enum.reduce(replace_funcs, {[], [], []}, fn {name, body, args, guards, module, tuple},
                                                  {private_functions, defpdelegates,
                                                   uniq_functions} ->
        :elixir_def.take_definition(module, tuple)

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
          {[private_function | private_functions], defpdelegates, uniq_functions}
        else
          defpdelegate =
            quote do
              defp unquote(name)(unquote_splicing(safe_args(args))),
                do: apply(__MODULE__.Private, unquote(name), unquote(safe_args(args)))
            end

          {[private_function | private_functions], [defpdelegate | defpdelegates],
           [function_signature | uniq_functions]}
        end
      end)

    module = """
    defmodule #{env.module}.Private do
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

  def __on_definition__(_env, :def, _name, _args, _guards, _body) do
  end

  def __on_definition__(_env, other, _name, _args, _guards, _body) do
  end
end
