% title
% Thiago Yukio Kikuchi Oliveira
\date

\pagebreak

Pipenote Tutorial
===============================================================================

Introdution
-------------------------------------------------------------------------------

This is a testing for my script

These lines should not be incorporated to the code.

  Right     Left     Center     Default
-------     ------ ---------    -------
     12     12        12            12
    123     123       123          123
      1     1          1             1

Table:  Demonstration of simple table syntax.



##begin mycode perl
# My perl code to $\sum_{i=1}^{n}i$
my $text = "Hello World!\n";
print $text;
my @ary = (
    'test', 1, "b", 2, 4, 5, 6, 7, { key => "value", key2 => 1 },
    1, 2, 3, 4, 5, 6, 7, 8
);

print Dumper(@ary);

##end


This is my another text.

##begin newcode

echo "Hello, World in bash script"
echo $TEXT

##end


##begin codeinpython python2.7

print "Hello, World in python" 
print 1+1

##end


##begin codeinruby ruby

puts  "Hello, World in ruby" 

##end

##begin codeinR Rscript

cat("Hello, World in R\n")

##end


##beginGlobal perl

	use strict;
	use warnings;
	use Data::Dumper;

##end

##beginGlobal bash

export	TEXT="Hello, I'm global"

##end
