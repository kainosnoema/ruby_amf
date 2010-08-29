$:.unshift(File.expand_path('../../', __FILE__))

require 'rubygems'
require 'benchmark'
require 'active_record'
require 'active_support/inflector'
require 'ext/ruby_amf_ext'
require 'amfora'

def bm_amf(t, n, kc, kp, o)
  c = kc.new
  p = kp.new
  td_c = c.deserialize(o).inspect
  td_p = p.deserialize(o).inspect
  cmp  = (td_c == td_p) ? '==' : '<>'
  
  puts "#{t}: #{td_c} #{cmp} #{td_p} (#{n})"
  
  Benchmark.bm do |x|
    x.report('AMF0::C   ') { n.times { c.deserialize(o) } }
    x.report('AMF0::Pure') { n.times { p.deserialize(o) } }
  end
  
  puts
end

d1, d2 = RubyAMF::Ext::AMF0Deserializer, AMF::Pure::AMF0Deserializer
times = 100000

t = "booleans (true)"
o = "\001\001"
bm_amf("read #{t}", times, d1, d2, o)

t = "booleans (false)"
o = "\001\000"
bm_amf("read #{t}", times, d1, d2, o)

t = "numbers"
o = [0, 5.5].pack('CG')
bm_amf("read #{t}", times, d1, d2, o)

t = "strings"
o = [0x02, 5, "hello"].pack('CnA*')
bm_amf("read #{t}", times, d1, d2, o)

t = "arrays"
o = [0x0A, 1, 0x02, 0x05, "hello"].pack('CNCna*')
bm_amf("read #{t}", times, d1, d2, o)

t = "hashes"
o = [0x08, 1, 0x05, "hello", 0x02, 0x05, "hello", 0x00, 0x09].pack('CNna*Cna*nC')
bm_amf("read #{t}", times, d1, d2, o)
