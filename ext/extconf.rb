require 'mkmf'

have_library('stdc++')

$CFLAGS << " -Wall " unless RUBY_PLATFORM =~ /solaris/
$CFLAGS << ' -g -ggdb -rdynamic -O0 -DDEBUG' if ENV['DEBUG']
$CFLAGS << " -Wconversion -Wsign-compare -Wwrite-strings -Wpointer-arith -fno-common -pedantic -Wno-long-long" if ENV['STRICT']
$CFLAGS << (ENV['CFLAGS'] || '')

dir_config('ruby_amf_ext')
create_makefile('ruby_amf_ext')