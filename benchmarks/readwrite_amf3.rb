$:.unshift(File.expand_path('../../', __FILE__))

require 'rubygems'
require 'benchmark'
require 'active_record'
require 'active_support/inflector'
require 'ext/ruby_amf_ext'
require 'amfora'

def bm_amf(t, o)
  n = 20000
  
  s1, d1 = RubyAMF::Ext::AMF3Serializer.new, RubyAMF::Ext::AMF3Deserializer.new
  s2, d2 = AMF::Pure::AMF3Serializer.new, AMF::Pure::AMF3Deserializer.new
  
  out_d1 = d1.deserialize(s1.serialize(o))
  out_d2 = d2.deserialize(s2.serialize(o))
  
  cmp1  = (o == out_d1) ? '==' : '<>'
  cmp2  = (o == out_d2) ? '==' : '<>'
  
  puts "AMF3::C     write/read #{t}: #{o.inspect} #{cmp1} #{out_d1.inspect} (#{n})"
  puts "AMF3::Pure  write/read #{t}: #{o.inspect} #{cmp2} #{out_d2.inspect} (#{n})"
  
  Benchmark.bm do |x|
    x.report { n.times { bin = s1.serialize(o); d1.deserialize(bin.clone()) } }
    x.report { n.times { bin = s2.serialize(o); d2.deserialize(bin.clone()) } }
  end
  
  puts
end

times = 50000
 
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
 
t = "strings"
o = "hello"
bm_amf(t, o)

t = "arrays"
o = ["bye"]
bm_amf(t, o)

t = "hashes"
o = {:bye => "bye", :number => 5.5, :another_hash => {:a_double => 200.34}}
bm_amf(t, o)
