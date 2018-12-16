defmodule PrivTest do
  use ExUnit.Case

  setup_all do
    defmodule Math do
      use Priv

      def add(x, y) do
        do_add(x, y)
      end

      defp do_add(x, y) do
        x + y
      end

      def divide(x, y) do
        do_divide(x, y)
      end

      defp do_divide(x, y) when y != 0 do
        {:ok, x / y}
      end

      defp do_divide(_x, 0) do
        {:error, :divide_by_zero}
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
      assert_raise(UndefinedFunctionError, fn ->
        assert Math.divide(4, 2) == 2
        assert Math.divide(4, 0) == {:error, :divide_by_zero}
      end)
    end
  end
end
