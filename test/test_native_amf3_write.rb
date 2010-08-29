require 'helper'

class Test_RUBY_AMF_AMF3_dump < Test::Unit::TestCase
  
  def serialize(str)
    RubyAMF::Ext::AMF3Serializer.new.serialize(str)
  end
  
  def deserialize(str)
    RubyAMF::Ext::AMF3Deserializer.new.deserialize(str)
  end
  
  def test_dump_integer_types
    assert_equal [0x04, 0b0000_1100].pack('CC*'), serialize(12)
    assert_equal [0x04, 0b1000_0010, 0b0010_1100].pack('CC*'), serialize(300)
  end
  
  def test_dump_double_types
    assert_equal [0x05, 5.5].pack('CG'), serialize(5.5)
    assert_equal [0x05, 1073741824].pack('CG'), serialize(1073741824)
  end
  
  def test_dump_string_types
    assert_equal [0x06, 0b1011, "hello"].pack('CCa*'), serialize("hello")
    assert_equal [0x06, 0b111,  "bye"  ].pack('CCa*'), serialize("bye")
  end
  
  def test_dump_true_type
    assert_equal [0x03].pack('C'), serialize(true)
  end
  
  def test_dump_false_type
    assert_equal [0x02].pack('C'), serialize(false)
  end
  
  def test_dump_nil_type
    assert_equal [0x01].pack('C'), serialize(nil)
  end
  
  def test_dump_time_type
    t = Time.now
    assert_equal [0x08, 0x01, (t.utc.to_f * 1000).to_i].pack('CCG'), serialize(t)
  end
  
  def test_dump_date_type
    d = Date.today
    assert_equal [0x08, 0x01, ((d.strftime("%s").to_i) * 1000).to_i].pack('CCG'), serialize(d)
  end
  
  def test_dump_array_type
    assert_equal [0x09, 0x01, 0x01].pack('CCC'), serialize([])
    assert_equal [0x09, 0x03, 0x01, 0x01].pack('CCCC'), serialize([nil])
    assert_equal [0x09, 0x03, 0x01, 0x06, 0b111, "bye"].pack('CCCCCa3'), serialize(["bye"])
  end
  
  def test_dump_string_refs
    str = "bye"
    assert_equal [
      0x09, 0b101, 0x01,
      0x06, 0b111, "bye",
      0x06, 0b0
    ].pack('CCCCCa3CC'), serialize([str, str])
    assert_equal [
      0x09, 0b111, 0x01,
      0x06, 0b111, "bye",
      0x06, 0b0,
      0x06, 0b0
    ].pack('CCCCCa3CCCC'), serialize([str, str, str])
  end
  
  def test_dump_hash_type
    assert_equal [0x0A, 0x0B, 0x01, 0x01].pack('CCCC'), serialize({})
    assert_equal [0x0A, 0x0B, 0x01, 0b111, "bye", 0x06, 0b0, 0x01].pack('CCCCa3CCC'), serialize({:bye => "bye"})
  end
   
  def test_dump_array_refs
    arr = []
    arr.push(arr)
    assert_equal [0x09, 0x03, 0x01, 0x09, 0x00].pack('CCCCC'), serialize(arr)
    arr.push(arr)
    assert_equal [0x09, 0b101, 0x01, 0x09, 0x00, 0x09, 0x00].pack('CCCCCCC'), serialize(arr)
  end
   
  def test_dump_dynamic_object_type
    o = Person.new
    o.name   = "Evan Owen"
    o.age    = 22
    o.gender = "m"

    assert_equal "\x0A\x0B\x39com.ekulnave.contacts.Person\x09name\x06\x13Evan Owen\x07age\x04\x16\x0dgender\x06\x03m\x01", serialize(o)
  end
  
  # def test_dump_object_ref
  #   n = '+32 488 478 282'
  #   pn1 = PhoneNumber.new(n, 'home')
  #   pn2 = PhoneNumber.new(n)
  #   c   = Card.new(pn1, pn2, pn2)
  #   
  #   expected = "\n\0271be.mrhenry.contacts.Card\ephone_numbers\t\a\001\n\037?be.mrhenry.contacts.PhoneNumber\vvalue\006\037+32 488 478 282\vlabel\006\thome\001\n\005\006\000\001\n\006"
  #   assert_equal expected, RUBY_AMF::AMF3.dump(c)
  # end
  
end
