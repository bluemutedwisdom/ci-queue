require 'test_helper'

module Integration
  class MinitestRedisTest < Minitest::Test
    include OutputTestHelpers

    def setup
      @redis_url = "redis://#{ENV.fetch('REDIS_HOST', 'localhost')}/7"
      @redis = Redis.new(url: @redis_url)
      @redis.flushdb
      @exe = File.expand_path('../../../exe/minitest-queue', __FILE__)
    end

    def test_buildkite_output
      out, err = capture_subprocess_io do
        system(
          { 'BUILDKITE' => '1' },
          @exe, 'run',
          '--queue', @redis_url,
          '--seed', 'foobar',
          '--build', '1',
          '--worker', '1',
          '--timeout', '1',
          '--max-requeues', '1',
          '--requeue-tolerance', '1',
          '-Itest',
          'test/dummy_test.rb',
          chdir: 'test/fixtures/',
        )
      end

      assert_empty err
      output = normalize(out.lines.last.strip)
      assert_equal '--- Ran 8 tests, 5 assertions, 1 failures, 1 errors, 1 skips, 3 requeues in X.XXs', output
    end

    def test_redis_runner
      out, err = capture_subprocess_io do
        system(
          @exe, 'run',
          '--queue', @redis_url,
          '--seed', 'foobar',
          '--build', '1',
          '--worker', '1',
          '--timeout', '1',
          '--max-requeues', '1',
          '--requeue-tolerance', '1',
          '-Itest',
          'test/dummy_test.rb',
          chdir: 'test/fixtures/',
        )
      end
      assert_empty err
      output = normalize(out.lines.last.strip)
      assert_equal 'Ran 8 tests, 5 assertions, 1 failures, 1 errors, 1 skips, 3 requeues in X.XXs', output

      out, err = capture_subprocess_io do
        system(
          @exe, 'retry',
          '--queue', @redis_url,
          '--seed', 'foobar',
          '--build', '1',
          '--worker', '1',
          '--timeout', '1',
          '--max-requeues', '1',
          '--requeue-tolerance', '1',
          '-Itest',
          'test/dummy_test.rb',
          chdir: 'test/fixtures/',
        )
      end
      assert_empty err
      output = normalize(out.lines.last.strip)
      assert_equal 'Ran 8 tests, 5 assertions, 1 failures, 1 errors, 1 skips, 3 requeues in X.XXs', output
    end

    def test_down_redis
      out, err = capture_subprocess_io do
        system(
          @exe, 'run',
          '--queue', 'redis://localhost:1337',
          '--seed', 'foobar',
          '--build', '1',
          '--worker', '1',
          '--timeout', '1',
          '--max-requeues', '1',
          '--requeue-tolerance', '1',
          '-Itest',
          'test/dummy_test.rb',
          chdir: 'test/fixtures/',
        )
      end
      assert_empty err
      output = normalize(out.lines.last.strip)
      assert_equal 'Ran 0 tests, 0 assertions, 0 failures, 0 errors, 0 skips, 0 requeues in X.XXs', output
    end

    def test_redis_reporter
      out, err = capture_subprocess_io do
        system(
          @exe, 'run',
          '--queue', @redis_url,
          '--seed', 'foobar',
          '--build', '1',
          '--worker', '1',
          '--timeout', '1',
          '--max-requeues', '1',
          '--requeue-tolerance', '1',
          '-Itest',
          'test/dummy_test.rb',
          chdir: 'test/fixtures/',
        )
      end
      assert_empty err
      output = normalize(out.lines.last.strip)
      assert_equal 'Ran 8 tests, 5 assertions, 1 failures, 1 errors, 1 skips, 3 requeues in X.XXs', output

      out, err = capture_subprocess_io do
        system(
          @exe, 'report',
          '--queue', @redis_url,
          '--build', '1',
          '--timeout', '1',
          chdir: 'test/fixtures/',
        )
      end
      assert_empty err
      output = normalize(out)
      assert_equal strip_heredoc(<<-END), output
        Waiting for workers to complete
        Ran 5 tests, 5 assertions, 1 failures, 1 errors, 1 skips, 3 requeues in X.XXs (aggregated)

        FAIL ATest#test_bar
        Expected false to be truthy.
            test/dummy_test.rb:9:in `test_bar'

        ERROR BTest#test_bar
        TypeError: String can't be coerced into Fixnum
            test/dummy_test.rb:28:in `+'
            test/dummy_test.rb:28:in `test_bar'

      END
    end

    private

    def normalize(output)
      freeze_timing(decolorize_output(output))
    end
  end
end
