defmodule PrivTest do
  use ExUnit.Case

  setup_all do
    defmodule MathUtils.Helpers do
      def triple(x), do: 3 * x

      defmodule Constants do
        def pi, do: 3.14
      end
    end

    defmodule Math do
      use Priv

      alias MathUtils.Helpers
      alias MathUtils.Helpers.Constants

      require Logger

      @doubler 2

      def add(x, y) do
        do_add(x, y)
      end

      defp do_add(x, y) do
        x + y
      end

      def divide(x, y) do
        do_divide(x, y)
      end

      @spec do_divide(number(), number()) :: {:ok, number()} | {:error, :divide_by_zero}
      defp do_divide(x, y) when y != 0 do
        {:ok, x / y}
      end

      defp do_divide(_x, 0) do
        {:error, :divide_by_zero}
      end

      def multiply(x) do
        do_multiply(x)
      end

      defp do_multiply(x) do
        x * @doubler
      end

      def triple_pi do
        do_triple_pi()
      end

      def pi do
        do_pi()
      end

      defp do_pi do
        Constants.pi()
      end

      defp do_triple_pi do
        Helpers.Constants.pi()
        |> Helpers.triple()
      end

      def add_with_log(x, y) do
        do_add_with_log(x, y)
      end

      defp do_add_with_log(x, y) do
        result = x + y
        Logger.info("#{x} + #{y} == #{result}")
        result
      end
    end

    :ok
  end

  describe "use priv" do
    test "should make private functions callable via __MODULE__.Private" do
      assert PrivTest.Math.Private.do_add(3, 5) == 8
    end

    test "public functions should still be able to call private functions" do
      assert PrivTest.Math.add(3, 5) == 8
    end

    test "private functions should not be callable" do
      assert_raise(UndefinedFunctionError, fn ->
        PrivTest.Math.do_add(3, 5)
      end)
    end

    test "guard causes on private fuctions are respected" do
      assert PrivTest.Math.divide(4, 2) == {:ok, 2}
      assert PrivTest.Math.divide(4, 0) == {:error, :divide_by_zero}
    end

    test "private functions should still be able to access module attributes" do
      assert PrivTest.Math.multiply(4) == 8
    end

    test "private functions should still be able to use aliases made in parent function" do
      assert PrivTest.Math.pi() == 3.14
      assert PrivTest.Math.triple_pi() == 3 * 3.14
    end

    test "private functions should still be able to access any requires" do
      assert ExUnit.CaptureLog.capture_log(fn ->
               PrivTest.Math.add_with_log(2, 3)
             end) =~ "2 + 3 == 5"
    end
  end
end
