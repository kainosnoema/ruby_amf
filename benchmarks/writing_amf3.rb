$:.unshift(File.expand_path('../../', __FILE__))

require 'rubygems'
require 'benchmark'
require 'active_record'
require 'active_support/inflector'
require 'ext/ruby_amf_ext'
require 'amfora'

def bm_amf(t, o, skipPure = false)
  n = 50000

  s1, s2 = RubyAMF::Ext::AMF3Serializer.new, AMF::Pure::AMF3Serializer.new

  td_c = s1.serialize(o).inspect
  td_p = s2.serialize(o).inspect unless skipPure
  cmp  = (td_c == td_p) ? '==' : '<>'
  
  puts "write #{t}: #{td_c} #{cmp} #{td_p} (#{n})"
  
  Benchmark.bm do |x|
    x.report('AMF3::C   ') { n.times { s1.serialize(o) } }
    x.report('AMF3::Pure') { n.times { s2.serialize(o) } } unless skipPure
  end
  
  puts
end
 
t = "booleans (true)"
o = true
bm_amf(t, o)
 
t = "booleans (false)"
o = false
bm_amf(t, o)

t = "doubles"
o = 5.5
bm_amf(t, o)
 
t = "times"
o = Time.now
bm_amf(t, o)

t = "dates"
o = Date.today
bm_amf(t, o, true)
 
t = "strings"
o = "hello"
bm_amf(t, o)

t = "arrays"
o = ["bye"]
bm_amf(t, o)

t = "hashes"
o = {:bye => "bye"}
bm_amf(t, o)
