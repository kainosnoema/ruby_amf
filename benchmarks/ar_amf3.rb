require 'lib/ruby_amf/pure'
require 'benchmark'

s1 = RubyAMF::Ext::AMF3Serializer.new
s2 = RubyAMF::Pure::AMF3Serializer.new

o = Name.limit(500).all
n = 1

s1.serialize(o) == s2.serialize(o)
s2 = RubyAMF::Pure::AMF3Serializer.new # to clear out cache... why doesn't it do this?

Benchmark.bm do |x|
  x.report('AMF3::C   ') { n.times { s1.serialize(o) } }
  x.report('AMF3::Pure') { n.times { s2.serialize(o) } }
end
