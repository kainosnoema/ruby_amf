$:.unshift(File.expand_path('../../', __FILE__))

require 'rubygems'
require 'benchmark'
require 'active_record'
require 'active_support/inflector'
require 'lib/ruby_amf/typed_hash'
require 'lib/ruby_amf/messages'
require 'lib/ruby_amf/remoting'
require 'lib/ruby_amf/class_mapping'
require 'ext/ruby_amf_ext'
require 'amfora'

def bm_amf(t, o)
  n = 50000

  d1, d2 = RubyAMF::Ext::AMF3Deserializer.new, AMF::Pure::AMF3Deserializer.new

  td_c = d1.deserialize(o).inspect
  td_p = d2.deserialize(o).inspect
  cmp  = (td_c == td_p) ? '==' : '<>'
  
  puts "read #{t}: #{td_c} #{cmp} #{td_p} (#{n})"
  
  Benchmark.bm do |x|
    x.report('AMF3::C   ') { n.times { d1.deserialize(o) } }
    x.report('AMF3::Pure') { n.times { d2.deserialize(o) } }
  end
  
  puts
end


t = "booleans (true)"
o = "\x03"
bm_amf(t, o)

t = "booleans (false)"
o = "\x02"
bm_amf(t, o)

t = "doubles"
o = [0x05, 5.5].pack('CG')
bm_amf(t, o)

t = "times"
o = [0x08, 0x01, (Time.now.to_f * 1000).to_i].pack('CCG')
bm_amf(t, o)

t = "dates"
o = [0x08, 0x01, ((Date.today.strftime("%s").to_i) * 1000).to_i].pack('CCG')
bm_amf(t, o)

t = "strings"
o = [0x06, 0b1011, "hello"].pack('CCa5')
bm_amf(t, o)

t = "arrays"
o = [0x09, 0x03, 0x01, 0x06, 0b111, "bye"].pack('CCCCCa3')
bm_amf(t, o)

t = "hashes"
o = [0x09, 0x01, 0b111, "bye", 0x06, 0b111, "bye", 0x01].pack('CCCa3CCa3C')
bm_amf(t, o)