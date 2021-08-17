#!/usr/bin/env ruby

# Simple script to collect idxstats data from samtools for both WGS and mtDNA
# files.
#
require 'open3'
require 'pathname'
require 'optparse'

options = {}

# Parse the command line arguments.
OptionParser.new do |opts|
	opts.banner = "Usage: stats.rb <bamdir> <mtdnadir>"
	opts.on('-b', '--bamdir=BAMDIR', "bamdir is required") do |bamdir|
		options[:bamdir] = bamdir
	end
	opts.on('-m', '--mtdnadir=MTDNADIR') do |mtdnadir|
		options[:mtdnadir] = mtdnadir
	end
end.parse!

raise "bamdir is required" if options[:bamdir].nil?
raise "mtdnadir is required" if options[:mtdnadir].nil?

bamdir = options[:bamdir]
mtdnadir = options[:mtdnadir]

# glob the bam files
bamfiles = Dir[bamdir << "/*.dedup.bam"]

# Get index stats for each bam file

puts "sample\tnReads\tnSize\tmtReads\tCN\tmitoReads\tmitoCN"
idxstats = []
bamfiles.each do |file|
	sample = file.split("/")[-1].split('.')[0]

	# run idxstats to get the number of reads and size for the autosomal 
	# chromosomes
	stdout, stderr, status = Open3.capture3("samtools idxstats #{file}")
	if status != 0 or stderr.length > 0
		raise "samtools failed for #{file}, #{status}, #{stderr}"
	end

	# tally the reads and genomic size
	numreads = 0
	size = 0
	numchrm = 0
	stdout.split("\n").each do |line|
		if /^chr[0-9]+[\s]/.match(line)
			values = line.split(/\s+/)
			numreads += values[2].to_i
			size += values[1].to_i
		end
		numchrm = line.split(/\s+/)[2].to_i if line.include?("chrM")
	end

	# compute the copy number
	cn = (numchrm * 150 * 2 / 16569) / (numreads * 150 * 2 / size)

	# compute number of chromsomal reads from the mitoscape procesed
	# files
	file = "#{mtdnadir}/#{sample}_MTDNA.bam"
	stdout, stderr, status = Open3.capture3("samtools idxstats #{file}")
	if status != 0 or stderr.length > 0
		raise "samtools failed for #{file}, #{status}, #{stderr}"
	end
	mtdnareads = 0
	stdout.split("\n").each do |line|
		mtdnareads = line.split(/\s+/)[2].to_i if line.include?("chrM")
	end
	cnmtdna = (mtdnareads * 150 * 2 / 16569) / (numreads * 150 * 2 / size)

	# report
	puts [ 
			sample, 
			numreads.to_s, 
			size, 
			numchrm.to_s, 
			cn.to_s,
			mtdnareads.to_s,
			cnmtdna.to_s
	].join("\t")
end
