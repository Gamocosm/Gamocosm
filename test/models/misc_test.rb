require 'test_helper'

class MiscTest < ActiveSupport::TestCase

  test 'monkey patches' do
    x = silence do
      1 / 0
    end
    assert x.error?, 'Silence should have caught exception and set return value to error'
    assert_raises(RuntimeError) do
      nil.error!
    end
  end
end
