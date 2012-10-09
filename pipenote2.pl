#!/usr/bin/env perl

=head1 NAME 

    Pipenote

=head1 SYNOPSIS
  This application requires Perl 5.10.0 or higher   
  This application requires, at least, the following modules to work:
    - Moose
    - MooseX::App::Cmd
    - MooseX::SimpleConfig


=head1 DESCRIPTION

=head1 AUTHOR

Thiago Yukio Kikuchi Oliveira

=head1 LICENSE

GNU General Public License

http://www.gnu.org/copyleft/gpl.html

=head1 METHODS

=cut

=for comment
###################################################################################################################
#
#   THIS SCRIPT REQUIRES SOME MODULES FROM CPAN TO WORK. TO LIST THEM PLEASE USE "perldoc <this_script_name>"
#
#   This script uses Modern Perl programing style (aka Enlightened Perl) if you don't know what it means, please
#   read the book 'Modern Perl' by chromatic (http://www.onyxneon.com/books/modern_perl/index.html).
#
#   This script use MooseX::App::Cmd (a Command Line Inteface Framework associated with Moose).
#   Please read the MooseX::App::Cmd Documentation before try to alter this script.
#
###################################################################################################################
=cut

use Moose;
use MooseX::Declare;
use Method::Signatures::Modifiers;
use Modern::Perl '2011';

# This is just a Main Cmd:App - don't touch
class Pipenote extends MooseX::App::Cmd {
    # Use to change de default command (help is the default)
    #sub default_command {  }
}

=for comment
#-------------------------------------------------------------------------------------------------------
# Base Command class
# Usually paramereters used by ALL commands shoud come here (e.g. config files with software path, etc)
#-------------------------------------------------------------------------------------------------------
=cut
class Pipenote::Command {
    # A Moose role for setting attributes from a simple configfile
    # It uses Config:Any so it can handle many formats (YAML, Apace, JSON, XML, etc..)
    with 'MooseX::SimpleConfig';

    # Control the '--configfile' option
    has '+configfile' => (
        traits      => ['Getopt'],
        cmd_aliases => 'c',
        isa         => 'Str',
        is          => 'rw',
        required    => 1,
        documentation => 'Configuration file (accept the following formats: YAML, CONF, XML, JSON, etc)',
    );

}


=for comment
#-------------------------------------------------------------------------------------------------------
# Command Classes 
# All Command should be create as classes and listed below
#-------------------------------------------------------------------------------------------------------

# Class Foo
#-------------------------------------------------------------------------------------------------------
=cut
class Pipenote::Command::Exec {
    use 5.10.0;
    extends 'MooseX::App::Cmd::Command';
    use File::Temp;
    use Data::Dumper;

    # Class attributes (program options - MooseX::Getopt)
    has 'input_file' => (
        isa           => 'Str',
        is            => 'rw',
        required      => 1,
        traits        => ['Getopt'],
        cmd_aliases   => 'i',
        documentation => 'Input file with markdown format',
    );

    has 'chunks' => (
        is          => 'rw',
        isa         => 'Str',
        traits      => ['Getopt'],
        cmd_aliases => 'o',

        #required      => 1,
        #default => sub{ [] },
        documentation => 'Chuncks that you want o execute',
    );

    # Description of this command in first help
    sub abstract { 'Execute your program'; }

    method extract_chunks_from_file {
        my @chunks;

        # Define input record separator as ''
        $/ = undef;

        # Read entire file
        open( my $in, '<', $self->input_file );
        my $text = <$in>;
        close($in);
        $/="\n";

        # Search for markdown chunks
        while ( $text =~ m/([\`\~]{3}\{?.*?[\`\~]{3})/sg ) {
            my $chunk = $1;
            # Save text after match
            my $after_match = $';
            
            # check if is a knitr include
            if ( $chunk =~ m/[\`\~]{3}\{r\s+.*child=[\'\"](.+)[\'\"]/ ) {
                my $include_file = $1;
                # check if file exists
                die "Cannot find child file: $include_file" unless (-e $include_file);

                # Get text for include file
                $/ = undef;
                open( my $in, '<', $include_file );
                my $include_text = <$in>; 
                close( $in );
                $/ = "\n";
                
                # redefine $text for include file text + rest of original text
                $text = $include_text.$after_match;
                
            }
            else{
                push @chunks, $chunk;
            }
        }
        
        return \@chunks;
    }

    method parse_chunks {
           # %globals keep piece of code to be inserted in the beginning of each
           # code
        my ( @indexed_chunks, %chunk_index, %globals );

        my $chunks = $self->extract_chunks_from_file();

        # languages;
        my @langs = qw/perl python bash/;
        my $i     = 0;                      # counter

        foreach my $chunk ( @{$chunks} ) {
            if ( $chunk =~ /[\`\~]{3}\{?(.*?)[\}?\n+\r+](.*)[\`\~]{3}/sg ) {
                my $header = $1;
                my $code   = $2;

                my @slices = split /\s+/, $header;
                my ( $language, $id );

                foreach my $lang (@langs) {
                    $language = $lang if $header =~ /\.?$lang/;
                }

                $id = $1 if $header =~ /\#(\S+)/;

                if ( $language && $id ) {
                    if ( $id =~ /^globals/ ) {
                        $globals{$language} = $code;
                    }
                    else {
                        $chunk_index{$id} = $i;
                        my %c = (
                            id       => $id,
                            idx      => $i,
                            language => $language,
                            code     => $code,
                            header   => $header
                        );
                        push( @indexed_chunks, \%c );
                        $i++;
                    }
                }
            }
        }

        return ( \%chunk_index, \@indexed_chunks, \%globals );
    }

    method execute_chunks ($chunks_ids,$index,$chunks,$globals) {
        my @aux = split /\s+/, $chunks_ids;

        foreach (@aux) {
            my $idx  = $index->{$_};
            my $code = "#!/usr/bin/env $chunks->[$idx]->{language}\n";

            #if ( $include_chunks{ $chunks->[$idx]->{language} } ) {
            #    $code .= join "",
            #      @{ $include_chunks{ $chunks->[idx]->{language} } };
            #}


            my $lang = $chunks->[$idx]->{language};
            $code .= $globals->{$lang} if $globals->{$lang};
            $code .= $chunks->[$idx]{code};

            # Create a temporary file to store the chunck;
            my $fh    = File::Temp->new();
            my $fname = $fh->filename;

            print $fh $code;

            # To export shell variables to current shell, you cannot call
            # the bash interpreter
            #if ( $chunks{$_}->{language} eq 'bash' ) {
            #    exec $code;
            #}
            #else {
            system("/usr/bin/env $chunks->[$idx]->{language} $fname");

            #}

        }
    }

    method check_chunks_list ($chunks_ids,$index) {
        my @aux = split /\s+/, $chunks_ids;
        my @err_ids;
        
        foreach my $chunk_id (@aux) {
            push( @err_ids, $chunk_id ) unless (exists $index->{$chunk_id});
        }

        if ( scalar @err_ids > 0 ) {
            die "Cannot find these chunks ids:\n" . join "\n", @err_ids;
        }
    }

    # method used to run the command
    method execute ($opt,$args) {

        my ( $index, $chunks, $globals ) = $self->parse_chunks();

        if ( $self->chunks ) {
            $self->check_chunks_list( $self->chunks, $index );
            $self->execute_chunks( $self->chunks, $index, $chunks, $globals );
        }
        else {
            say join "\n",
                sort { $index->{$a} <=> $index->{$b} } keys %{$index};
        }
    }
}

class Pipenote::Command::Doc {
    use 5.10.0;
    extends 'MooseX::App::Cmd::Command';
    use File::Temp;
    use FindBin qw($Bin);
    use Cwd;
    use HTML::Scrubber;

   
    # Class attributes (program options - MooseX::Getopt)
    has 'input_file' => (
        isa           => 'Str',
        is            => 'rw',
        required      => 1,
        traits        => ['Getopt'],
        cmd_aliases   => 'i',
        documentation => 'Input file with markdown format and code chunks',
    );

    has 'pretty_latex' => (
        is            => 'rw',
        isa           => 'Bool',
        traits        => ['Getopt'],
        cmd_aliases     => 'p',
        required      => 0,
        documentation => 'Convert code chunks to latex using minted enviroment Boolean variable.',
    );
 
    has 'no_code' => (
        is            => 'rw',
        isa           => 'Bool',
        traits        => ['Getopt'],
        cmd_aliases     => 'n',
        required      => 0,
        documentation => 'Not show code.',
    );
   
    has 'beamer_version' => (
        is            => 'rw',
        isa           => 'Bool',
        traits        => ['Getopt'],
        cmd_aliases     => 'b',
        required      => 0,
        documentation => 'Create a presentation using beamer.',
    );


    # Description of this command in first help
    sub abstract { 'Generate the notes of your pipeline'; }
    
    # method used to run the command
    method execute ($opt,$args) {
       
       
       my $output;
       # Parsing Shell and other languages
       my $current_dir = getcwd;
       mkdir "$current_dir/pipenote";
       my $file = $self->input_file;
       my $Rcmd = "Rscript -e 'library(knitr); setwd(\"$current_dir\"); knit(\"$file\")'";

       system($Rcmd);
       $file =~ s/\.Rmd/\.md/;
       
       #Removing latex comment 
       my $sed = "sed -i -e '/^% latex/d' $file";
       system($sed);
       $sed = "sed -i -e '/^%\$/d' $file";
       system($sed);

       my $pdf_filename;
       $pdf_filename = $1 if $file =~ /\/?^(.*)\.md/;

       #open(my $out,'>', $outfilename);
       #print $out $self->parse_note_file;
       #close($out);
       
       # Executing RweavePandoc (ascii package)
       #system("$Bin/bin/pandoc.Rscript ".$outfilename);       
       
       #my $string='%';

       #system("perl -i -ne 'print unless /^$string/' $current_dir/pipenote/sweaved.md");       
       
       # Create file markdown without code
       my $cmd = "perl -0777 -pne 's/`{3}[r\{].*?`{3}//isg' $file > ".$pdf_filename."_nocode.md";
       system($cmd);
 
       $cmd = "cat $file | perl -pne 's/\.pdf/\.png/g'| pandoc -s -t html --highlight-style tango  -o ".$pdf_filename.".html";
       system($cmd);
       
       $cmd = "perl -i -0777 -pe 's/\\<table.*?\\<\\/table\\>//isg' $file";
       system($cmd);

       # Executing Pandoc
       $cmd = "pandoc -t latex --highlight-style tango --template $Bin/template/pandoc_template2.tex -o $current_dir/pipenote/".$pdf_filename.".tex " . $file;
       system($cmd);
       $cmd = "pandoc -t latex --highlight-style tango --template $Bin/template/pandoc_template2.tex -o  $current_dir/pipenote/".$pdf_filename."_nocode.tex " . $pdf_filename."_nocode.md";
       system($cmd);


      # Executing PDFLaTeX
       system("pdflatex -shell-escape $current_dir/pipenote/".$pdf_filename.".tex");
       system("pdflatex -shell-escape $current_dir/pipenote/".$pdf_filename."_nocode.tex");

    }
}


=for comment
#-------------------------------------------------------------------------------------------------------
# Running application 
#-------------------------------------------------------------------------------------------------------
=cut
class main {
    Pipenote->run;
}

