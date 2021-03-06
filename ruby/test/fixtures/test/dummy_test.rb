require 'test_helper'

class ATest < Minitest::Test
  def test_foo
    skip
  end

  def test_bar
    assert false
  end

  def test_flaky
    if defined?(@@already_ran) && @@already_ran
      assert true
    else
      @@already_ran = true
      assert false
    end
  end
end

class BTest < Minitest::Test
  def test_foo
    assert true
  end

  def test_bar
    1 + '1'
  end
end
