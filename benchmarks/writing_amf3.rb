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
require 'lib/ruby_amf/pure'
# require 'amfora'

def bm_amf(t, o, n = 5000, skipPure = false)

  s1, s2 = RubyAMF::Ext::AMF3Serializer.new, RubyAMF::Pure::AMF3Serializer.new

  td_c = s1.serialize(o).inspect
  td_p = s2.serialize(o).inspect unless skipPure
  cmp  = (td_c == td_p) ? '==' : '<>'
  
  puts "write #{t}: #{cmp} (#{n})"
  
  Benchmark.bm do |x|
    x.report('AMF3::C   ') { n.times { s1.serialize(o) } }
    x.report('AMF3::Pure') { n.times { s2.serialize(o) } } unless skipPure
  end
  
  puts
end

def rand_string(length = 20)
  chars = ('a'..'z').to_a
  (1..length).collect{|a| chars[rand(chars.size)] }.join
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
bm_amf(t, o, 5000)
 
t = "strings"
o = "hello"
bm_amf(t, o)

t = "arrays"
o = ["bye"]
bm_amf(t, o)

t = "hashes"
o = {:bye => "bye"}
bm_amf(t, o)

t = "lots o'times"
tt = []

500.times { tt << Time.now }
bm_amf(t, tt, 10)

t = "lots o'strings"
ss = []

500.times { ss << rand_string }
bm_amf(t, ss, 10)

t = "lots o'arrays"
aa = []

500.times { aa << [rand_string] }
bm_amf(t, aa, 10)

t = "lots o'hashes"
hh = []

500.times { hh << {rand_string => rand_string} }
bm_amf(t, hh, 10)
