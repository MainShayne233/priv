defmodule Priv do
  @moduledoc """
  A macro for converting all private functions into public functions that exist under
  __MODULE__.Private
  """

  defmacro __using__(_env) do
    quote do
      Module.register_attribute(__MODULE__, :replace_register, accumulate: true)
      Module.register_attribute(__MODULE__, :all_register, accumulate: true)
      @on_definition Priv
      @before_compile Priv
    end
  end

  defmacro __before_compile__(env) do
    replace_funcs = Module.get_attribute(env.module, :replace_register)

    all_funcs = Module.get_attribute(env.module, :all_register)

    Module.put_attribute(env.module, :replace_ran, true)

    new_functions =
      Enum.map(replace_funcs, fn {name, body, args, module, tuple} ->
        :elixir_def.take_definition(module, tuple)

        quote do
          def unquote(name)(unquote_splicing(args)), unquote(body)
        end
      end)

    quote do

      defmodule Private do
        unquote(new_functions)
      end
    end
  end

  def __on_definition__(env, :defp, name, args, guards, body) do
    if Module.get_attribute(env.module, :replace_ran) != true do
      tuple = {name, length(args)}

      Module.put_attribute(
        env.module,
        :replace_register,
        {name, body, args, env.module, tuple}
      )

      Module.put_attribute(env.module, :all_register, {name, body, args, env.module, tuple})
    end
  end

  def __on_definition__(_env, :def, _name, _args, _guards, _body) do
  end
end

defmodule Sample do
  use Priv

  @moduledoc """
  Documentation for Priv.
  """

  def i_am_public do
    :world
  end

  def i_am_public_and_call_a_private_function do
  end

  defp i_am_private do
    :came_from_private
  end

  defp i_am_also_private(x, y) do
    x + y
  end
end
