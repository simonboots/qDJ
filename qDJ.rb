#!/usr/bin/ruby
# ==Synopsis
#
# qDJ: A basic queueing tool
#
# ==Usage
#
# qDJ.rb [OPTION]
#
# -h, --help:
#    show help
#
# -e FILE1 FILE2 ... FILEN, --enqueue FILE1 FILE2 ... FILEN:
#    enqueues files
#
# -d, --dequeue:
#    dequeues next file
#
# -c, --clear:
#    clears queue
#
# -s, --size:
#    size of enqueued files
#
# -l, --list:
#    lists content of queue (with ID)
#
# -x ID, --delete ID:
#    deletes item with id ID
#
# -r, --randomize:
#    randomizes queue



$: << '/Library/Ruby/Gems/1.8/gems/fsdb-0.5/lib/'

require 'getoptlong'
require 'fsdb'
require 'rdoc/usage'
require 'yaml'
require 'pathname'

QDB = 'files'

##### Class QDJ #####

class QDJ

  def initialize
    @scriptpath = Pathname.new($0).realpath.dirname.to_s
    @pwd = Pathname.new(".").realpath
    File.open(@scriptpath + '/qDJconfig.yaml') { |yf| @config = YAML::load(yf)['config'] }
    @dbh = FSDB::Database.new(@config['db_path'])
    @dbh[QDB] ||= []
  end

  def enqueue(file)
    @dbh.edit QDB do |list|
      filepath = Pathname.new(@pwd + file)
      list << filepath.cleanpath
    end
  end
  
  def dequeue
    retval = nil
    @dbh.edit QDB do |list|
      retval = list.shift
    end
    
    retval
  end
  
  def size
    @dbh[QDB].size
  end
  
  def clear
    @dbh.edit QDB do |list|
      list.clear
    end
  end
  
  def delete(id)
    @dbh.edit QDB do |list|
      list.delete_at(id-1)
    end
  end
  
  def emergency_fill
    empath = @config['emergency_path']
    raise "Emergency directory doesn't exist!" unless File.directory?(empath)
    
    dir = Dir.new(empath)
    dir.each do |file|
      if File.file?(empath + '/' + file)
        self.enqueue(empath + '/' + file)
      end
    end
    
    self.randomize
  end
  
  def randomize
    @dbh.edit QDB do |list|
      list.randomize!
    end
  end
  
  def print_list
    counter = 1
    @dbh[QDB].each do |file|
      puts counter.to_s + ': ' + file
      counter += 1
    end
  end

end

##### Array enhancements #####

class Array
  def randomize
    a=self.dup
    result = []
    self.length.times do
      result << a.slice!(rand(a.length))
    end
    return result
  end
  def randomize!
    a=self.dup
    result = []
    self.length.times do
      result << a.slice!(rand(a.length))
    end
    self.replace result
  end
end

##### Main #####

opts = GetoptLong.new(
    [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
    [ '--enqueue', '-e', GetoptLong::NO_ARGUMENT ],
    [ '--dequeue', '-d', GetoptLong::NO_ARGUMENT],
    [ '--clear', '-c', GetoptLong::NO_ARGUMENT],
    [ '--size', '-s', GetoptLong::NO_ARGUMENT],
    [ '--list', '-l', GetoptLong::NO_ARGUMENT],
    [ '--delete', '-x', GetoptLong::REQUIRED_ARGUMENT],
    [ '--randomize', '-r', GetoptLong::NO_ARGUMENT]
  )

dj = QDJ.new

option_available = false

opts.each do |opt, arg|
  option_available = true
  case opt
    
  when '--help'
    RDoc::usage('usage')
    
  when '--enqueue'
    ARGV.each do |file|
      dj.enqueue(file)
    end
    
  when '--dequeue'
    file = dj.dequeue
    if file.nil?
      dj.emergency_fill
      file = dj.dequeue
    end
    puts file
    
  when '--clear'
    dj.clear
    
  when '--size'
    puts dj.size
    
  when '--list'
    dj.print_list
    
  when '--delete'
    dj.delete arg.to_i
    
  when '--randomize'
    dj.randomize
  end
end

RDoc::usage('usage') unless option_available
