defmodule Voile.Migration.PerformanceTest do
  @moduledoc """
  Performance testing utilities for migration importers.
  """

  def benchmark_user_import(method \\ :optimized, batch_size \\ 1000) do
    IO.puts("🚀 Starting user import benchmark...")
    IO.puts("Method: #{method}, Batch size: #{batch_size}")

    start_time = System.monotonic_time(:microsecond)

    result =
      case method do
        :optimized -> Voile.Migration.UserImporter.import_all(batch_size)
        :legacy -> Voile.Migration.UserImporter.import_all_legacy(batch_size)
      end

    end_time = System.monotonic_time(:microsecond)
    duration_ms = (end_time - start_time) / 1000

    IO.puts("\n📊 PERFORMANCE RESULTS")
    IO.puts("=" <> String.duplicate("=", 50))
    IO.puts("Method: #{String.upcase(to_string(method))}")
    IO.puts("Batch Size: #{batch_size}")
    IO.puts("Duration: #{Float.round(duration_ms, 2)} ms")
    IO.puts("Users Inserted: #{result.inserted}")
    IO.puts("Users Skipped: #{result.skipped}")
    IO.puts("Errors: #{result.errors}")

    if result.inserted > 0 do
      users_per_second = Float.round(result.inserted / (duration_ms / 1000), 2)
      ms_per_user = Float.round(duration_ms / result.inserted, 4)
      IO.puts("Rate: #{users_per_second} users/second")
      IO.puts("Average: #{ms_per_user} ms/user")
    end

    IO.puts("=" <> String.duplicate("=", 50))

    {result, duration_ms}
  end

  def compare_methods(batch_sizes \\ [500, 1000, 2000]) do
    IO.puts("🔍 Comparing user import methods across different batch sizes...")

    results =
      Enum.map(batch_sizes, fn batch_size ->
        IO.puts("\n📏 Testing batch size: #{batch_size}")

        # Test optimized method
        {opt_result, opt_time} = benchmark_user_import(:optimized, batch_size)

        # Test legacy method (if needed for comparison)
        # {leg_result, leg_time} = benchmark_user_import(:legacy, batch_size)

        %{
          batch_size: batch_size,
          optimized: %{result: opt_result, time: opt_time}
          # legacy: %{result: leg_result, time: leg_time}
        }
      end)

    IO.puts("\n📈 COMPARISON SUMMARY")
    IO.puts("=" <> String.duplicate("=", 60))

    Enum.each(results, fn %{batch_size: bs, optimized: opt} ->
      IO.puts("Batch Size #{bs}: #{Float.round(opt.time, 2)} ms (#{opt.result.inserted} users)")
    end)

    results
  end
end
