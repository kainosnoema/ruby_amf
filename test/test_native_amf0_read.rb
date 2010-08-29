require 'helper'

class Test_RUBY_AMF_AMF0_load < Test::Unit::TestCase
  
  def deserialize(str)
    RubyAMF::Ext::AMF0Deserializer.new.deserialize(str)
  end
  
  def test_load_true_type
    assert_equal true, deserialize("\001\001")
  end
  
  def test_load_false_type
    assert_equal false, deserialize("\001\000")
  end
  
  def test_load_nil_type
    assert_equal nil, deserialize("\x05")
  end
  
  def test_load_undef_type
    assert_equal nil, deserialize("\x06")
  end
  
  def test_load_double_type
    assert_equal 5.55, deserialize([0, 5.55].pack('CG'))
    assert_equal 1073741824, deserialize([0, 1073741824].pack('CG'))
  end
  
  def test_load_string_type
    assert_equal "hello", deserialize([0x02, 5, "hello"].pack('CnA*'))
    assert_equal "bye", deserialize([0x02, 0x03, "bye"].pack('CnA*'))
  end
  
  def test_load_time_type
    t = Time.now
    assert_in_delta t.to_f, deserialize([0x0B, (t.to_f * 1000).to_i, 0x00].pack('CGn')).to_f, 0.001
  end
  
  def test_load_array_type
    assert_equal [], deserialize([0x0A, 0].pack('CN'))
    assert_equal [nil], deserialize([0x0A, 1, 0x05].pack('CNC'))
    assert_equal ['hello'], deserialize([0x0A, 1, 0x02, 0x05, "hello"].pack('CNCna*'))
  end
   
  def test_load_hash_type
    assert_equal({"hello" => "hello"}, deserialize([0x08, 1, 0x05, "hello", 0x02, 0x05, "hello", 0x00, 0x09].pack('CNna*Cna*nC')))
  end
  
end
