require 'helper'

class Test_RUBY_AMF_AMF0_dump < Test::Unit::TestCase
  
  def serialize(str)
    RubyAMF::Ext::AMF0Serializer.new.serialize(str)
  end
  
  def deserialize(str)
    RubyAMF::Ext::AMF0Deserializer.new.deserialize(str)
  end

  def test_dump_double_types
    assert_equal [0, 5.5].pack('CG'), serialize(5.5)
    assert_equal [0, 1073741824].pack('CG'), serialize(1073741824)
  end
  
  def test_dump_string_types
    assert_equal [0x02, 0x05, "hello"].pack('CnA*'), serialize("hello")
    assert_equal [0x02, 0x03, "bye"].pack('CnA*'), serialize("bye")
  end
   
  def test_dump_true_type
    assert_equal "\001\001", serialize(true)
  end
  
  def test_dump_false_type
    assert_equal "\001\000", serialize(false)
  end
  
  def test_dump_nil_type
    assert_equal "\05", serialize(nil)
  end
  
  def test_dump_time_type
    t = Time.now
    assert_equal [0x0B, (t.to_f * 1000).to_i, 0x00].pack('CGn'), serialize(t)
  end
  
  # def test_dump_date_type
  #   d = Date.today
  #   assert_equal [0x08, 0x01, ((d.strftime("%s").to_i) * 1000).to_i].pack('CCG'), serialize(d)
  # end
  
  def test_dump_array_type
    assert_equal [0x0A, 0].pack('CN'), serialize([])
    assert_equal [0x0A, 1, 0x05].pack('CNC'), serialize([nil])
    assert_equal [0x0A, 1, 0x02, 0x05, "hello"].pack('CNCna*'), serialize(["hello"])
  end
   
  def test_dump_hash_type
    assert_equal [0x08, 1, 0x05, "hello", 0x02, 0x05, "hello", 0x00, 0x09].pack('CNna*Cna*nC'), serialize({"hello" => "hello"})
  end
  
end
