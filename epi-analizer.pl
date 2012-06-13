#use strict;
use DBI;

my $connection_string =
  "DBI:Pg:dbname=baza_mocvd;host=localhost; port=5432";
my $user     = "kklos";
my $password = "";

#my $connection_string="DBI:Pg:dbname=baza_mocvd;host=localhost; port=5432";
#my $user="krzys";
#my $password="";

my $ar     = @ARGV;    #ilosc ar. wej.
my @logtab = undef;
my $filename;
my @wynik;      #tablica z wynikami do wyswietlenia na koniec
my @result;     #tablica z wynikami do wyswietlenia na koniec
my $count;      #licznik warstw
my $do_bazy;    #tablica do ktorej zapisywane sa dane do wpisania w layers
my $v_cdte = 4.5;
my $v_hgte = 3;

if ( $ar == 1 ) {
	$filename = $ARGV[0];    #plik wejsciowy
}
else {
	print "\nZla ilosc argumentow!";
	exit;
}

#poczatek programu

#print "\n\nEpi-analizer is free software (GNU GPL). It is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY. You can contact me at klos.krzysztof\@gmail.com \n\n";

my @output_table;
my %out_hash;

#TODO Jak dodac komentarz do tabeli? na koncu wiersza komentarz do danej warstwy?
my %zero_hash = (
	"Step"	 	=> "",
	"Loops"   	=> "",
	"Time"		=> "",
	"TMGa_1"    	=> "",
	"TMGa_2"	=> "",
	"TMAl_1"	=> "",
	"TMIn_1"       	=> "",
	"TMIn_2"       	=> "",
	"AsH3_1"	=> "",
	"PH3_1"		=> "",
	"SiH4_1"	=> "-\t",
	"DEZn_1"	=> "-\t",
	"Press"		=> "",
	"Temp."		=> "",
	"Sumflow" =>	""
);

#do @output_table dodawane beda hashe zawierajace parametry wyjsciowe
#do
#na poczatku glownej petli oceniajacej kroki ,jesli wykryty zostanie IMP, lub CdTe lub HgTe, to zostanie stworzony nowy, pusty obiekt %out_hash i zostanie on wypełniony
#w kazdym kroku, ktory spelnia warunki do wzrostu, na koniec zostanie dodany jako anonymous hashdo output table.
# Po zakonczeniu analizowania receptury odpowiedni skrypt wypluje wynik na konsole, lub wprowadzi do bazy (dobrze jakby klucze hasha mialy takie same nazwy, jak tabele w bazie)
#TODO inicjowanie hasha na poczatku krokow
#TODO dopisanie dodawania do tabeli @result na %out
#TODO napisanie procedury wyswietlajacej w odpowiedniej kolejnosci zawartosc @output_table
#TODO napisanie procedury wstawiajacej do bazy danych - || - - || - - || - - || -
#TODO testy i porownanie wynikow z @result i hashy
%state = (
	"DummyHyd_1.source" => "500",
	"DummyHyd_1.run"    => "close",

	"H2.line"         => "close",
	"H2.run"          => "close",
	"N2.line"         => "open",
	"N2.run"          => "open",
	"MOVac"           => "close",
	"PumpBypass"      => "open",
	"IGS"             => "on",
	"ReactorValve"    => "open",
	"VentVac"         => "close",
	"MainPump"        => "on",
	"Heater"          => "off",
	"Cooling"         => "on",
	"Control"         => "off",
	"Parameters"      => "on",
	"Hg_Heater"       => "off",
	"ComputerEnable"  => "on",
#Zrodla
	"AsH3_1.line"     => "close",
	"AsH3_1.run"      => "close",
	"AsH3_1.source"   => "1",
	"AsH3_1.push"   => "100",

	"TMGa_1.line"     => "close",
	"TMGa_1.run"      => "close",
	"TMGa_1.source "  => "5",
	"TMGa_1.push"     => "50",
	"TMGa_1.press"    => "1200",

	"TMGa_2.line"    => "close",
	"TMGa_2.run"     => "close",
	"TMGa_2.source"  => "50",
	"TMGa_2.push"    => "50",
	"TMGa_2.press"   => "1200",

	"TMAl_1.line"    => "close",
	"TMAl_1.run"     => "close",
	"TMAl_1.source"  => "50",
	"TMAl_1.push"    => "50",
	"TMAl_1.press"   => "1200",

	"TMIn_1.line"    => "close",
	"TMIn_1.run"     => "close",
	"TMIn_1.source"  => "50",
	"TMIn_1.push"    => "50",
	"TMIn_1.press"   => "1200",
	
	"TMIn_2.line"    => "close",
	"TMIn_2.run"     => "close",
	"TMIn_2.source"  => "50",
	"TMIn_2.push"    => "50",
	"TMIn_2.press"   => "1200",


	"DEZn_1.line"   => "close",
	"DEZn_1.run"    => "close",
	"DEZn_1.source" => "20",
	"DEZn_1.dilute" => "100",
	"DEZn_1.push"   => "50",
	"DEZn_1.inject" => "20",
	"DEZn_1.press"  => "1200",

	"SiH4_1.line"       => "close",
	"SiH4_1.run"        => "close",
	"SiH4_1.source"     => "1",
	"SiH4_1.dilute"     => "100",
#	"SiH4_1.push"       => "50",
	"SiH4_1.inject"     => "50",
	"SiH4_1.press"      => "1200",

	"RunHydride"      => "500",
	"VentHydride"     => "200",
	"RunDopant"       => "500",
	"VentDopant"      => "150",
	"Rotation"        => "10",
	"LinerPurge"      => "500",
	"RunMO"           => "500",
	"VentMO"          => "200",
	"ReactorPress"    => "1000",
	"ReactorTemp"     => "20",
	"HgTemp"          => "20",
	"Message"         => "",
	"Duration"        => "",
	"flow"            => ""
);
my $receptura = slurp2string($filename);
$receptura =~ s/#.*?\n//mg;    #czyszczenie z komentarzy receptury

$receptura =~ s/^.*?layer\s*\{\n?//s;    #wyrzucenie naglowka z receptury

#procedura dzielaca recepture na kroki i zwracajaca je w postaci tablicy
my @epi_steps = recs_split($receptura);

#iterowanie po kazdym elemencie @epi_steps.
#1. sprawdzenie, czy w kroku jest loop
#	-jesli jest, to wywolanie metody analizujacej loopy
#	-jesli nie ma, to podzial kroku na rozkazy po przecinkach i uaktualnianie %state o rozkazy:
#	Pierwszy rozkaz z kroku sprawdzic czy ma czas trwania, jesli nie ma, to sprawdzic czy jest until w ostatnim
#	 i od razu przerobic rozkaz z pierwszego kroku, i usunac ostatni element tablicy kroku podzielonego na rozkazy.
#		1.1 sprawdzenie, czy w w kroku jest slowo until
#			- jesli jest to podzial receptury na rozkazy po przecinku i dodawanie rozkazow do %state, z pominieciem ostatniego kroku
#			Wlasciwie, to mozna po prostu dodac warunek sprawdzajacy, czy w danym rozkazie wystepuje until i jesli wystepuje, to pomijac go.
#			Nie ma potrzeby wykorzystywac informacji, o warunku w until

#		Po dodaniu wszystkich rozkazow nalezy sprawdzic warunki:
#		CdTe:
#		 ReactorTemp,DMCd_1.line/run=open DIPTe_1.line/run=open, sumflow>1000
#		HgTe:
#			ReactorTemp, DIPTe_1.line/run=open, DMCd_1.line/run=close, sumflow<1000, HgTemp>170,
#		Kazde z nich ustawia flage HgTe lub CdTe, nie moga one byc obie aktywne, bo wtedy error.

#		 i jesli sa spelnione to wywolac procedure dopisujaca wiersz w output

push(
	@result,
	[
		"Loops", "Suma",   "HgTe",   "CdTe",   "TDMAAs", "EI",
		"Cd/Te", "GrTemp", "HgTemp", "As,ppm", "EI,ppm"
	]
);

my $loop_count=1;
foreach $step (@epi_steps) {
	
	analyse_step($step);
}

#wyswietlenie wynikow

#for ($i=0;$i<$#wynik+1; $i++) {
#	my $row=join('\t',@wynik[0..$#wynik]->[$i]);
#	print $row;
#}

#for $i ( 0 .. $#result ) {
#	$s = join( "\t", @{ $result[$i] } );
#	print "$s\n";
#}

my $header="\n\nStep\tLoops\tTime\tTMGa_1\tTMGa_2\tTMAl_1\tTMIn_1\tTMIn_2\tAsH3_1\tPH3_1\tSiH4_1\t\tDEZn_1\t\tPress\tTemp.\tSumflow\t\tComment\n";
my $f_header="\nStep;Loops;Time;TMGa_1;TMGa_2;TMAl_1;TMIn_1;TMIn_2;AsH3_1;PH3_1;SiH4_1;DEZn_1;Press;Temp.;Sumflow;Comment\n";
print $header;

# print the whole thing with indices
my $to_file;
$to_file=$filename."\n".$f_header;

for $i ( 0 .. $#out_tab ) {

	#  for $role ( keys %{ $out_tab[$i] } ) {
	#	$out_tab[$i]{'doping'}=~m/(\w+)\s+(\d+.\d+|\d+)\/(\d+.\d+|\d+)s/;
	#	my $d_typ=$1;
	#	my $d_stz=$2;
	#	my $d_time=$3;
	my $out_string = "$out_tab[$i]{Step}\t$out_tab[$i]{Loops}\t$out_tab[$i]{Time}\t$out_tab[$i]{TMGa_1}\t$out_tab[$i]{'TMGa_2'}\t$out_tab[$i]{'TMAl_1'}\t$out_tab[$i]{'TMIn_1'}\t$out_tab[$i]{'TMIn_2'}\t$out_tab[$i]{'AsH3_1'}\t$out_tab[$i]{PH3_1}\t$out_tab[$i]{SiH4_1}\t$out_tab[$i]{'DEZn_1'}\t$out_tab[$i]{'Press'}\t$out_tab[$i]{'Temp.'}\t$out_tab[$i]{'Sumflow'}\t$out_tab[$i]{'Message'}\n";

	my $f_out_string = "$out_tab[$i]{Step};$out_tab[$i]{Loops};$out_tab[$i]{Time};$out_tab[$i]{TMGa_1};$out_tab[$i]{'TMGa_2'};$out_tab[$i]{'TMAl_1'};$out_tab[$i]{'TMIn_1'};$out_tab[$i]{'TMIn_2'};$out_tab[$i]{'AsH3_1'};$out_tab[$i]{PH3_1};$out_tab[$i]{SiH4_1};$out_tab[$i]{'DEZn_1'};$out_tab[$i]{'Press'};$out_tab[$i]{'Temp.'};$out_tab[$i]{'Sumflow'};$out_tab[$i]{'Message'}\n";
	print $out_string;
	$to_file=$to_file.$f_out_string;
}

$filename =~ s/(.*?)\..*/$1/;

#$to_file =~ s/\t\t/\t/g;

open (MYFILE, ">$filename\.csv");
 print MYFILE $to_file;
 close (MYFILE);


#print("Czy chcesz wstawic dane do bazy? [tn]:\n");
#$in2db = <STDIN>;
#chomp($in2db);
$in2db="f";


if ( $in2db =~ m/t/ ) {

	#Wstawianie wynikow do bazy danych
	$filename =~ m/(^\d+)/;
	$process_id = $1;

	my $in_str = hash2string( $process_id, \@out_tab );
	delete_from("delete from erp.layer where process_id=$process_id");
	insert(
		"erp.layer",
"(process_id,layer_id,loops,t_hgte,t_cdte,cd2te_ratio,doping,growth_temp,hg_temp,v_hgte,v_cdte)",
		$in_str
	);
}
else {
	print "\nKoniec!\n";
}

#------------------------------------------------------------------------
#funkcja result2insert_string przerabiajaca tabele result na stringa gotowego do
#wstawienia w jednej transakcji

#stworzenie stringa z pojedynczego hasha obiektu out_tab
#wstawienie go do bazy danych
#przygotowanie w bazie danych pol na przeplyw cdte_flow i hgte_flow i chyba stezen
#modyfikacja arkusza layers_from_db (dodanie wspolczynnika R zamiast sumy, usuniecie kasownia formul przy wstawianiu

#

sub hash2string {
	my $process_id = @_[0];
	my @tab        = @{ @_[1] };
	my $str;

	#wpisywanie NULL w puste pola
	# print the whole thing one at a time
	for $i ( 0 .. $#tab ) {
		for $key ( keys %{ $tab[$i] } ) {
			if ( $tab[$i]{"HgTe"} eq "" ) {
				$tab[$i]{"HgTe"} = 0;
			}
			elsif ( $tab[$i]{"CdTe"} eq "" ) {
				$tab[$i]{"CdTe"} = 0;
			}
			elsif ( $tab[$i]{"doping"} eq "" ) {
				$tab[$i]{"doping"} = '';
			}
			elsif ( $tab[$i]{$key} eq "" ) {
				$tab[$i]{$key} = 'NULL';
			}
			elsif ( $tab[$i]{$key} eq undef ) {
				$tab[$i]{$key} = 'NULL';
			}
		}
	}

	#przygotowanie stringa do wstawienia do bazy
	for $i ( 0 .. @tab - 1 ) {
		if ( $tab[$i]{CdTe} + $tab[$i]{HgTe} < 12 ) {
			next;
		}
		my $s =
"$tab[$i]{layer_id},$tab[$i]{Loops},$tab[$i]{HgTe},$tab[$i]{CdTe},$tab[$i]{'Cd/Te'},'$tab[$i]{doping}',$tab[$i]{GrTemp},$tab[$i]{HgTemp},$tab[$i]{v_hgte},$tab[$i]{v_cdte}"
		  ; #,$tab[$i]{'TDMAAs'},$tab[$i]{'as_ppm'},$tab[$i]{'EI'},$tab[$i]{'ei_ppm'},$tab[$i]{'hgte_flow'},,$tab[$i]{'cdte_flow'}\n";

		$str = $str . "($process_id,$s),";
	}
	$str =~ s/,$//;    #wyciecie niepotrzebnego przecinka na koncu stringa
	print "\n$str\n";
	return $str;
}

#################################################
sub result2insert_string {
	my $process_id = @_[0];
	my @tab        = @{ @_[1] };
	my $str;

	#wpisywanie NULL w puste pola
	#	for $i ( 0 .. $#tab) {
	#		for ($k = 0; $k <= $#{$tab[$i]}; $k++) {
	#	        	print "@{$tab[$i]}->[$k]\n";
	#			if(@{$tab[$i]}->[$k]=="") {
	#				@{$tab[$i]}->[$k]="NULL";
	#				print ("Pusty!");
	#			}
	#		}
	#	}

	#	#usuwanie zbednych kolumn
	#	for $i ( 0 .. $#tab) {
	#		my @f = split(",",@{$tab[$i]});
	#		my
	#		print DAT $f[0] . "," . $f[5]-$f[9] . "\n";

	#generowanie stringa
	for $i ( 0 .. $#tab ) {

		#my $s=join(",",@{$tab[$i]});
		my @t = @{ $tab[$i] };
		my $s = "$t[0],$t[1],$t[2],$t[3],$t[4],'$t[5]',$t[6],$t[7],$t[8],$t[9]";
		print "$s\n";
		$str = $str . "($process_id,$s),";
	}
	$str =~ s/,$//;    #wyciecie niepotrzebnego przecinka na koncu stringa
	print "\n$str\n";
	return $str;
}

#-----------------------------------------------------------------
#procedura slurpingujaca plik do stringa po nazwie pliku z biezacego katalogu
sub slurp2string {
	my $filename = @_[0];
	my @file     = undef;
	local $/ = undef;

	open( FILE, $filename ) or die "nie mozna otworzyc pliku: $filename";
	binmode FILE;
	my $string = <FILE>;
	close FILE;
	return $string;
}

#--------------------------------------------------------------
#przerabianie petli na tabele
#arg wejsciowym jest string z petla
sub loop2table {
	my $loop_body = @_[0];
	my @steps;
	while ( $loop_body =~ m/\s*(\d*[:.]?\d*:?\d+)\s+(.*?);/sg ) {

		#		print "$1\n";
		#		print "$2\n";
		push( @steps, [ $1, $2 ] );
	}
	return @steps;
}

#--------------------------------------------------------------
#obliczanie czasu calkowitego petli
#procedura zwraca czas sumaryczny z 1 kolumny tabeli
sub loop_time {
	my @tab  = @_;
	my $time = 0;
	foreach my $t (@tab) {
		$time = $time + $t->[0];
	}
	return $time;
}

#--------------------------------------------------------------
#obliczanie czasu otwarcia prekursorow w petli
#procedura zwraca czas sumaryczny z 1 kolumny tablicy w pierwszym argumencie
sub old_time {
	my @tab      = @{ @_[0] };
	my $start    = @_[1];
	my $koniec   = @_[2];
	my $przebieg = @_[3];
	my $time     = 0;
	my $flag     = 0;

	foreach my $t (@tab) {
		if ( $t->[1] =~ m/$start/is ) {
			$flag = 1;
			$time = 0;
		}
		if ( $t->[1] =~ m/$koniec/is ) { $flag = 0; }

		if ( $flag == 1 ) {
			$time = $time + $t->[0];
		}
	}
	return $time;
}

#--------------------------------------------------------------
#obliczanie czasu otwarcia prekursorow w petli
#procedura zwraca czas sumaryczny z 1 kolumny tablicy w pierwszym argumencie
#TODO ta funkcja jest do przerobienia w analizator IMPu zwracajacy wszystkie parametry IMPu, lub jej wywolywanie w innej funkcji analizujacej
#TODO w ktorej jako start i koniec sa pobierane sukcesywnie kolejne interesujace nas prekursory... TDMAAs i EI powinny byc pobierane ostatnie i
#TODO powinny nadpisywac szybkosci przeplywu okreslone w momencie obliczania przeplywow na podstawie DMCd i DIPTe
sub mo_time {
	my @tab    = @{ @_[0] };
	my $start  = @_[1];
	my $s_flag = 0;            #start liczenia czasu
	my $koniec = @_[2];
	my $k_flag = 0;            #koniec liczenia czasu
	my $p_flag = 0
	  ; #flaga do limitowania przebiegow do dwoch (0 pierwszy i 1 drugi przebieg)
	my @time_tab;
	my $time;
	my %return_hash;

	for ( $i = 0 ; $i < $#tab + 1 ; $i++ ) {

#aktualizacja $state w kazdej iteracji, o rozkazy zawarte w drugiej kolumnie @tab
		state_step_actualization( $tab[$i][1] );

#obliczenie szybkosci przeplywu dla HgTe przy zalozeniu, ze to HgTe jest pierwszym krokiem w petli IMP
#tylko jedno wejscie na samym poczatku petli po krokach IMPu(Loop'a)
		if ( $s_flag == 0 && $i == 0 ) {
			$return_hash{"hgte_flow"} = get_upperflow() . "/" . get_lowerflow();
		}

		if ( $tab[$i][1] =~ m/$start/is ) {
			$s_flag = 1;
			$time   = 0;
		}
		if ( $tab[$i][1] =~ m/$koniec/is && $s_flag == 1 ) {
			$k_flag = 1;
		}
		if ( $s_flag == 1 && $k_flag == 0 ) {
			$time = $time + $tab[$i][0];

#wywolanie w ostatnim kroku kwalifikujacym sie obliczenia stezenia (aby ominac problemy z DMCd, ktory jest otwierany z Line zanim Run otwarty
# i zanim przeplywy sie zwieksza)
			if ( $i < $#tab ) {
				if ( $tab[ $i + 1 ][1] =~ m/$koniec/is ) {

#wywolanie procedury obliczajacej stezenie prekursora i stezenie wrzucone do pierwszego elementu @tab
#czyli @tab o parzystym indeksie 0,2,4 to beda stezenia, a 1,3,5 to czasy otwarcia.
					if ( $start =~ m/TDMAAs/is ) {
						push( @time_tab, sprintf( "%.2f", get_tdmaas_ppm() ) );
						$return_hash{"as_ppm"} =
						  sprintf( "%.2f", get_tdmaas_ppm() );
					}
					elsif ( $start =~ m/EI/is ) {
						push( @time_tab, sprintf( "%.2f", get_ei_ppm() ) );
						$return_hash{"ei_ppm"} =
						  sprintf( "%.2f", get_ei_ppm() );
					}
					elsif ( $start =~ m/DMCd/is ) {
						push( @time_tab, sprintf( "%.2f", get_dmcd_pp() ) );
						$return_hash{"dmcd_pp"} =
						  sprintf( "%.2f", get_dmcd_pp() );
						push( @time_tab, sprintf( "%.2f", get_dipte_pp() ) );
						$return_hash{"dipte_pp"} =
						  sprintf( "%.2f", get_dipte_pp() );
						$return_hash{"cdte_flow"} =
						  get_upperflow() . "/" . get_lowerflow();
					}
					elsif ( $start =~ m/DIPTe/is ) {
						push( @time_tab, sprintf( "%.2f", get_dipte_pp() ) );
						$return_hash{"dipte_pp"} =
						  sprintf( "%.2f", get_dipte_pp() );
					}
				}
			}
		}
		if ( $s_flag == 1 && $k_flag == 1 ) {
			push( @time_tab, $time );
			$return_hash{"time"} = $time;
			$s_flag              = 0;
			$k_flag              = 0;
		}
		if ( $s_flag == 1 && $i == $#tab && $p_flag == 0 ) {

			#tylko raz tu wejsc powinien
			$i      = -1;
			$p_flag = 1;
		}

	}
	return @time_tab;
}

#--------------------------------------------------------------
#obliczanie czasu otwarcia prekursorow w petli
#procedura zwraca czas sumaryczny z 1 kolumny tablicy w pierwszym argumencie
#TODO ta funkcja jest do przerobienia w analizator IMPu zwracajacy wszystkie parametry IMPu, lub jej wywolywanie w innej funkcji analizujacej
#TODO w ktorej jako start i koniec sa pobierane sukcesywnie kolejne interesujace nas prekursory... TDMAAs i EI powinny byc pobierane ostatnie i
#TODO powinny nadpisywac szybkosci przeplywu okreslone w momencie obliczania przeplywow na podstawie DMCd i DIPTe

sub imp_params {
	my @tab    = @{ @_[0] };
	my $start  = @_[1];
	my $s_flag = 0;            #start liczenia czasu
	my $koniec = @_[2];
	my $k_flag = 0;            #koniec liczenia czasu
	my $p_flag = 0
	  ; #flaga do limitowania przebiegow do dwoch (0 pierwszy i 1 drugi przebieg)
	my @time_tab;
	my $time;
	my %return_hash;
	my $counter = 0
	  ; #zliczanie ile razy s_flag=1 i k_flag=1, czyli ile razy otwarto  i zamknieto w IMPie zawor

	#ustawianie wartosci domyslnych
	$return_hash{"time"}    = "";
	$return_hash{"counter"} = 0;

	for ( $i = 0 ; $i < $#tab + 1 ; $i++ ) {

#aktualizacja $state w kazdej iteracji, o rozkazy zawarte w drugiej kolumnie @tab
		state_step_actualization( $tab[$i][1] );

#obliczenie szybkosci przeplywu dla HgTe przy zalozeniu, ze to HgTe jest pierwszym krokiem w petli IMP
#tylko jedno wejscie na samym poczatku petli po krokach IMPu(Loop'a)
		if ( $s_flag == 0 && $i == 0 ) {
			$return_hash{"hgte_flow"} = get_upperflow() . "/" . get_lowerflow();
		}

		if ( $tab[$i][1] =~ m/$start/is ) {
			$s_flag = 1;
			$time   = 0;
		}
		if ( $tab[$i][1] =~ m/$koniec/is && $s_flag == 1 ) {
			$k_flag = 1;
		}
		if ( $s_flag == 1 && $k_flag == 0 ) {
			$time = $time + $tab[$i][0];

#wywolanie w ostatnim kroku kwalifikujacym sie obliczenia stezenia (aby ominac problemy z DMCd, ktory jest otwierany z Line zanim Run otwarty
# i zanim przeplywy sie zwieksza)
			if ( $i < $#tab ) {
				if ( $tab[ $i + 1 ][1] =~ m/$koniec/is ) {

#wywolanie procedury obliczajacej stezenie prekursora i stezenie wrzucone do pierwszego elementu @tab
#czyli @tab o parzystym indeksie 0,2,4 to beda stezenia, a 1,3,5 to czasy otwarcia.
					if ( $start =~ m/TDMAAs/is ) {
						$return_hash{"as_ppm"} =
						  sprintf( "%.2f", get_tdmaas_ppm() );
					}
					elsif ( $start =~ m/EI/is ) {
						$return_hash{"ei_ppm"} =
						  sprintf( "%.2f", get_ei_ppm() );
					}
					elsif ( $start =~ m/DMCd/is ) {
						$return_hash{"dmcd_pp"} =
						  sprintf( "%.2f", get_dmcd_pp() );
						$return_hash{"cdte_flow"} =
						    sprintf( "%d", get_upperflow() ) . "/"
						  . sprintf( "%d", get_lowerflow() );
						if ( $state{"DMCd_1.line"} =~ m/open/is ) {
							$return_hash{"dmcd_pp"} =
							  sprintf( "%.2f", get_dmcd_pp() );
							$return_hash{"dipte_pp"} =
							  sprintf( "%.2f", get_dipte_pp() );
							$return_hash{"cd2te"} = sprintf( "%.2f",
								$return_hash{"dmcd_pp"} /
								  $return_hash{"dipte_pp"} );
						}
					}
					elsif ( $start =~ m/DIPTe/is ) {

				 #w IMPie w 2 przejsciu dla CdTe wartosci i tak zostana zapisane
						$return_hash{"dipte_pp"} =
						  sprintf( "%.2f", get_dipte_pp() );
						$return_hash{"cdte_flow"} =
						    sprintf( "%d", get_upperflow() ) . "/"
						  . sprintf( "%d", get_lowerflow() );
					}
				}
			}
		}
		if ( $s_flag == 1 && $k_flag == 1 ) {
			$counter = $counter + 1;
			if ( $counter == 2 ) {
				$return_hash{"hgte_time"} = $time;
			}
			push( @time_tab, $time );
			$return_hash{"time"}    = $time;
			$return_hash{"counter"} = $counter;
			$s_flag                 = 0;
			$k_flag                 = 0;
		}
		if ( $s_flag == 1 && $i == $#tab && $p_flag == 0 ) {

			#tylko raz tu wejsc powinien
			$i      = -1;
			$p_flag = 1;
		}

	}
	if ( $return_hash{"counter"} == 0 && $start =~ m/TDMAAs/is ) {
		$return_hash{"as_ppm"} = sprintf( "%.2f", get_tdmaas_ppm() );
		$return_hash{"time"} = "*";

	}
	return %return_hash;
}

#----------------------------------------------------------
#new IMP HgTe time- sumflow <1200sccm
sub hgte_time {
	my @tab    = @{ @_[0] };
	my $start  = @_[1];
	my $s_flag = 0;            #start liczenia czasu
	my $koniec = @_[2];
	my $k_flag = 0;            #koniec liczenia czasu
	my $p_flag = 0
	  ; #flaga do limitowania przebiegow do dwoch (0 pierwszy i 1 drugi przebieg)
	my @time_tab;
	my $time;

	for ( $i = 0 ; $i < $#tab + 1 ; $i++ ) {

#aktualizacja $state w kazdej iteracji, o rozkazy zawarte w drugiej kolumnie @tab
		state_step_actualization( $tab[$i][1] );

		if ( get_sumflow() < 1200 && $s_flag == 0 ) {
			$s_flag = 1;
			$time   = 0;
		}
		if ( get_sumflow() > 1200 && $s_flag == 1 ) {
			$k_flag = 1;
		}
		if ( $s_flag == 1 && $k_flag == 0 ) {
			$time = $time + $tab[$i][0];
		}
		if ( $s_flag == 1 && $k_flag == 1 ) {
			break;
			$s_flag = 0;
			$k_flag = 0;
		}
		if ( $s_flag == 1 && $i == $#tab && $p_flag == 0 ) {

			#tylko raz tu wejsc powinien
			$i      = -1;
			$p_flag = 1;
		}

	}
	return $time;
}

#--------------------------------------------------------------
#dzielenie stringa z receptura na kroki
sub recs_split {
	my $receptura = @_[0];
	my @epi_steps;

	while ( $receptura =~ m/^(.*?);\n?/s ) {
		my $temp_step = $1;
		if ( $1 =~ m/loop/ ) {
			$receptura =~ s/(loop\s+\d+\s*\{.*?\})\n?//s;
			push( @epi_steps, $1 );
		}
		else {
			push( @epi_steps, $temp_step );
			$receptura =~ s/^(.*?);\n?//s;
		}
	}
	return @epi_steps;
}

#dzielenie  pojedynczego rozkazu na urzadzenie i jego stan, czyli klucz i jego wartosc, operator jest zaniedbywany
#funkcja zwraca tablice, w ktorej pierwszym elementem jest klucz, a drugim wartosc
sub order_split {
	my $order = @_[0];
	my $key;
	my $value;

	if ( $order =~ m/^\s*(\w+\.\w+|\w+)\s*(\sto\s|=|==|<<|>>|\sfollow\s|\s+)\s*(\w+\.\w+|\w+)\s*/)
	{

#TODO Follow komende trudno zaimplementowac, trzeba pamietac gdzies powiazanie...
		$key   = $1;
		$value = $3;
	}
	elsif ( $order =~ m/begin\s*stat|end\s*stat/ ) {

		# rozkaz prawidlowy, ale nic z nim nie robimy
	}
	#informacja w recepturze - opis kroku
	elsif ( $order =~ m/"(.*?)"/ ) {
		$key = "Message";
		$value = $1; 	
	}
	else {
		print("\n\nNie udalo sie podzielic na klucz/wartosc rozkazu!:\n$order\n\n");
		exit;
	}

	return [ $key, $value ];
}

#dzielenie zawartosci petli na kroki, potem na rozkazy i aktualizacja hasha %state
sub state_loop_actualization {
	my $loop_body = @_[0];
	$loop_body =~ s/\s*$//s;

	#podzial na kroki
	my @steps = split( /;/, $loop_body );

	#wyciecie czasu trwania i wstawienie go jako duration?
	foreach $step (@steps) {
		$step =~
		  s/^\s*(\d*[:.]?\d*:?\d+)\s+(.*)/\2/;   #wyciecie czasu trwania z kroku
		    #	my $step_time=$1;#w IMP wlasciwie nas to nie interesuje
		for ($step) {
	            s/^\s+//;
	            s/\s+$//;
        	}
		my @orders = split( /,/, $step );

#zwykle kroki: 1 jako liczba petli i Suma jako czas trwania wyciagniety z pierwszego kroku.
		foreach $s (@orders) {
			my @k_v = order_split($s);
			$state{ $k_v[0]->[0] } = $k_v[0]->[1];
		}
	}
	$state{'flow'} =
	  sprintf( "%d", get_upperflow() ) . "/" . sprintf( "%d", get_lowerflow() );
}

#----------------------------------------------------------------------
#dzielenie zawartosci kroku na rozkazy i aktualizacja hasha %state
sub state_step_actualization {
	my $step = @_[0];

	#wyciecie czasu trwania i wstawienie go jako duration? To tylko pomysl...
	#my $step_time=$1;#w IMP wlasciwie nas to nie interesuje
	chomp($step);
	my @orders = split( /,/, $step );

#zwykle kroki: 1 jako liczba petli i Suma jako czas trwania wyciagniety z pierwszego kroku.
	foreach $s (@orders) {
		my @k_v = order_split($s);
		$state{ $k_v[0]->[0] } = $k_v[0]->[1];
	}
	$state{'flow'} =
	  sprintf( "%d", get_upperflow() ) . "/" . sprintf( "%d", get_lowerflow() );
}

#----------------------------------------------------------------------
#procedura, w ktorej sprawdzane sa warunki na osadzanie AlGaAs i innych
sub algaas_check {
	if ( $state{'AsH3_1.line' || $state{'AsH3_1.run'}}  =~ m/close/ ) {
		return 0;
	}
	else {
		if ( $state{'TMGa_1.line'} =~ m/close/ && $state{'TMGa_2.line'} =~ m/close/ ) { return 0; }
		if ( $state{'TMGa_1.run'} =~ m/close/ && $state{'TMGa_2.run'} =~ m/close/) { return 0; }
		if ( $state{'TMAl_1.run'} =~ m/close/ ) { return 0; }
		if ( $state{'TMAl_1.line'} =~ m/close/ ) { return 0; }
	}
	
	if($state{'ReactorTemp'}<500) {return 0;}
	return 1;
}

sub gaas_check {
	if ( $state{'AsH3_1.line' || $state{'AsH3_1.run'}}  =~ m/close/ ) {
		return 0;
	}
	else {
		if ( $state{'TMGa_1.line'} =~ m/close/ && $state{'TMGa_2.line'} =~ m/close/ ) { return 0; }
		if ( $state{'TMGa_1.run'} =~ m/close/ && $state{'TMGa_2.run'} =~ m/close/) { return 0; }
	}
	
	if($state{'ReactorTemp'}<500) {return 0;}
	return 1;
}

sub alas_check {
	if ( $state{'AsH3_1.line' || $state{'AsH3_1.run'}}  =~ m/close/ ) {
		return 0;
	}
	else {
		if ( $state{'TMAl_1.line'} =~ m/close/ || $state{'TMAl_1.run'} =~ m/close/) { return 0; }
	}
	
	if($state{'ReactorTemp'}<500) {return 0;}
	return 1;
}

sub ingaas_check {
	if ( $state{'AsH3_1.line'}  =~ m/close/ ) { return 0; }
	if ( $state{'AsH3_1.run'}   =~ m/close/ ) { return 0; }
	if ( $state{'TMGa_1.line'} =~ m/close/ && $state{'TMGa_2.line'} =~ m/close/ ) { return 0; }
	if ( $state{'TMGa_1.run'} =~ m/close/ && $state{'TMGa_2.run'} =~ m/close/) { return 0; }
	if ( $state{'TMIn_1.run'} =~ m/close/ &&  $state{'TMIn_2.run'} =~ m/close/) { return 0; }
	if ( $state{'TMIn_2.line'} =~ m/close/ &&  $state{'TMIn_2.line'} =~ m/close/) { return 0; }
	
	if($state{'ReactorTemp'}<500) {return 0;}
	return 1;
}


sub inas_check {
	if ( $state{'AsH3_1.line'}  =~ m/close/ ) { return 0; }
	if ( $state{'AsH3_1.run'}   =~ m/close/ ) { return 0; }
	if ( $state{'TMIn_1.run'} =~ m/close/ &&  $state{'TMIn_2.run'} =~ m/close/) { return 0; }
	if ( $state{'TMIn_2.line'} =~ m/close/ &&  $state{'TMIn_2.line'} =~ m/close/) { return 0; }
	
	if($state{'ReactorTemp'}<500) {return 0;}
	return 1;
}


sub ingaasp_check {
	if ( $state{'AsH3_1.line'} =~m/close/ || $state{'AsH3_1.run'} =~ m/close/ || $state{'PH3_1.line'} =~ m/close/ || $state{'PH3_1.run'} =~ m/close/ ) {
		return 0;
	}
	else {
		if ( $state{'TMGa_1.line'} =~ m/close/ && $state{'TMGa_2.line'} =~ m/close/ ) { return 0; }
		if ( $state{'TMGa_1.run'} =~ m/close/ && $state{'TMGa_2.run'} =~ m/close/) { return 0; }
		if ( $state{'TMIn_1.run'} =~ m/close/ &&  $state{'TMIn_2.run'} =~ m/close/) { return 0; }
		if ( $state{'TMIn_2.line'} =~ m/close/ &&  $state{'TMIn_2.line'} =~ m/close/) { return 0; }
	}
	
	if($state{'ReactorTemp'}<500) {return 0;}
	return 1;
}

sub ingap_check {
	if ( $state{'PH3_1.line'} =~ m/close/ || $state{'PH3_1.run'} =~ m/close/ ) {
		return 0;
	}
	else {
		if ( $state{'TMGa_1.line'} =~ m/close/ && $state{'TMGa_2.line'} =~ m/close/ ) { return 0; }
		if ( $state{'TMGa_1.run'} =~ m/close/ && $state{'TMGa_2.run'} =~ m/close/) { return 0; }
		if ( $state{'TMIn_1.run'} =~ m/close/ &&  $state{'TMIn_2.run'} =~ m/close/) { return 0; }
		if ( $state{'TMIn_2.line'} =~ m/close/ &&  $state{'TMIn_2.line'} =~ m/close/) { return 0; }
	}
	
	if($state{'ReactorTemp'}<500) {return 0;}
	return 1;
}

sub inalgaas_check {
	if ( $state{'AsH3_1.line'} =~m/close/ || $state{'AsH3_1.run'} =~ m/close/ ) {
		return 0;
	}
	else {
		if ( $state{'TMGa_1.line'} =~ m/close/ && $state{'TMGa_2.line'} =~ m/close/ ) { return 0; }
		if ( $state{'TMGa_1.run'} =~ m/close/ && $state{'TMGa_2.run'} =~ m/close/) { return 0; }
		if ( $state{'TMIn_1.run'} =~ m/close/ &&  $state{'TMIn_2.run'} =~ m/close/) { return 0; }
		if ( $state{'TMIn_2.line'} =~ m/close/ &&  $state{'TMIn_2.line'} =~ m/close/) { return 0; }
		if ( $state{'TMAl_1.line'} =~ m/close/ || $state{'TMAl_1.run'} =~ m/close/) { return 0; }
	}
	
	if($state{'ReactorTemp'}<500) {return 0;}
	return 1;
}

sub ingaalp_check {
	if ( $state{'AsH3_1.line'} =~m/close/ || $state{'AsH3_1.run'} =~ m/close/ || $state{'PH3_1.line'} =~ m/close/ || $state{'PH3_1.run'} =~ m/close/ ) {
		return 0;
	}
	else {
		if ( $state{'TMGa_1.line'} =~ m/close/ && $state{'TMGa_2.line'} =~ m/close/ ) { return 0; }
		if ( $state{'TMGa_1.run'} =~ m/close/ && $state{'TMGa_2.run'} =~ m/close/) { return 0; }
		if ( $state{'TMIn_1.run'} =~ m/close/ &&  $state{'TMIn_2.run'} =~ m/close/) { return 0; }
		if ( $state{'TMIn_2.line'} =~ m/close/ &&  $state{'TMIn_2.line'} =~ m/close/) { return 0; }
		if ( $state{'TMAl_1.line'} =~ m/close/ || $state{'TMAl_1.run'} =~ m/close/) { return 0; }
	}
	
	if($state{'ReactorTemp'}<500) {return 0;}
	return 1;
}
sub inalp_check {
	if ( $state{'PH3_1.line'} =~ m/close/ || $state{'PH3_1.run'} =~ m/close/ ) {
		return 0;
	}
	else {
		if ( $state{'TMIn_1.run'} =~ m/close/ &&  $state{'TMIn_2.run'} =~ m/close/) { return 0; }
		if ( $state{'TMIn_2.line'} =~ m/close/ &&  $state{'TMIn_2.line'} =~ m/close/) { return 0; }
		if ( $state{'TMAl_1.run'} =~ m/close/ ) { return 0; }
		if ( $state{'TMAl_1.line'} =~ m/close/ ) { return 0; }
	}
	
	if($state{'ReactorTemp'}<500) {return 0;}
	return 1;
}


sub inp_check {
	if ( $state{'PH3_1.line'} =~ m/close/ || $state{'PH3_1.run'} =~ m/close/ ) {
		return 0;
	}
	else {
		if ( $state{'TMIn_1.run'} =~ m/close/ &&  $state{'TMIn_2.run'} =~ m/close/) { return 0; }
		if ( $state{'TMIn_1.line'} =~ m/close/ &&  $state{'TMIn_2.line'} =~ m/close/) { return 0; }
	}
	
	if($state{'ReactorTemp'}<500) {return 0;}
	return 1;
}


sub gap_check {
	if ( $state{'PH3_1.line'} =~ m/close/ || $state{'PH3_1.run'} =~ m/close/ ) {
		return 0;
	}
	else {
		if ( $state{'TMGa_1.line'} =~ m/close/ && $state{'TMGa_2.line'} =~ m/close/ ) { return 0; }
		if ( $state{'TMGa_1.run'} =~ m/close/ && $state{'TMGa_2.run'} =~ m/close/) { return 0; }
	}
	
	if($state{'ReactorTemp'}<500) {return 0;}
	return 1;
}

sub alp_check {
	if ( $state{'PH3_1.line'} =~ m/close/ || $state{'PH3_1.run'} =~ m/close/ ) {
		return 0;
	}
	else {
		if ( $state{'TMAl_1.run'} =~ m/close/ ) { return 0; }
		if ( $state{'TMAl_1.line'} =~ m/close/ ) { return 0; }
	}
	
	if($state{'ReactorTemp'}<500) {return 0;}
	return 1;
}
sub N2_in_MO_check {
	if ( ($state{'TMGa_1.line'} =~ m/open/ || $state{'TMGa_2.line'} =~ m/open/ || $state{'TMAl_1.line'} =~ m/open/ || $state{'TMIn_1.line'} =~ m/open/ || $state{'TMIn_2.line'} =~ m/open/ || $state{'DEZn_1.line'} =~ m/open/ )
		&& ( $state{'N2.line'} =~ m/open/ ) )
	{
		return 0;
	}
	return 1;
}

#------------------------------------------------------
#Procedura obliczajaca przeplyw w dolnym wlocie reaktora
#działa na globalnym hashu %state
#Hydrides

sub get_lowerflow {
	my $lower = $state{'RunHydride'};
	if ( $state{'AsH3_1.run'} =~ m/open/ ) {
		$lower = $lower + $state{'AsH3_1.source'} + $state{'AsH3_1.push'};
	}
	
	if ( $state{'PH3_1.run'} =~ m/open/ ) {
		$lower = $lower + $state{'PH3_1.source'} + $state{'PH3_1.push'};
	}
	
	if ( $state{'DummyHyd_1.run'} =~ m/open/ ) {
		$lower = $lower + $state{'DummyHyd_1.source'};
	}
	return $lower;
}

#------------------------------------------------------
#Procedura obliczajaca przeplyw sumaryczny przez gorny wlot reaktora
#działa na globalnym hashu %state

sub get_upperflow {
	my $upper = $state{'RunMO'} + $state{'RunDopant'};
	if ( $state{'TMGa_1.run'} =~ m/open/ ) {
		$upper = $upper + $state{'TMGa_1.source'} + $state{'TMGa_1.push'};
	}
	
	if ( $state{'TMGa_2.run'} =~ m/open/ ) {
		$upper = $upper + $state{'TMGa_2.source'} + $state{'TMGa_2.push'};
	}
	
	if ( $state{'TMAl_1.run'} =~ m/open/ ) {
		$upper = $upper + $state{'TMAl_1.source'} + $state{'TMAl_1.push'};
	}
	
	if ( $state{'TMIn_1.run'} =~ m/open/ ) {
		$upper = $upper + $state{'TMIn_1.source'} + $state{'TMIn_1.push'};
	}
	
	if ( $state{'TMIn_2.run'} =~ m/open/ ) {
		$upper = $upper + $state{'TMIn_2.source'} + $state{'TMIn_2.push'};
	}
	
	if ( $state{'DEZn_1.run'} =~ m/open/ ) {
		$upper = $upper + $state{'DEZn_1.inject'} + $state{'DEZn_1.push'};
	}
	
	if ( $state{'SiH4_1.run'} =~ m/open/ ) {
		$upper = $upper + $state{'SiH4_1.inject'};
	}
	
	if ( $state{'DummyMO.run'} =~ m/open/ ) {
		$upper = $upper + $state{'DummyMO_1.source'};
	}
	
	return $upper;
}

#------------------------------------------------------
#Procedura obliczajaca przeplyw sumaryczny przez reaktor
#działa na globalnym hashu %state

sub get_sumflow {
	my $sumflow = get_upperflow() + get_lowerflow;    # $state{'Rotation'}+
	return $sumflow;
}

#-----------------------------------------------------------------------
#Procedura obliczajaca przeplyw source otwartego zrodla na podstawie nazwy zrodla.
#działa na globalnym hashu %state

sub get_source_flow {
	my $source_name = @_[0];    #string z labelem zrodla, ktorego przeplyw mamy wyciagnac
	
	if (   $state{$source_name.'.line'} =~ m/open/is
		&& $state{$source_name.'.run'} =~ m/open/is )
	{
		return $state{$source_name.'.source'};
	}
	return "";
}

#-----------------------------------------------------------------------

#Procedura obliczajaca stezenie DIPTe w reaktorze w mbar.
#działa na globalnym hashu %state

sub get_dipte_pp {
	my $dipte_temp = 21;                              #stala temperatura DIPTe
	my $source     = $state{'DIPTe_1.source'};
	my $pressure   = $state{'DIPTe_1.press'};
	my $rp         = $state{'ReactorPress'};

	my $cp_bubbler = ( 10**( 8.288 - 2309 / ( $dipte_temp + 273.15 ) ) ) / 0.76;
	my $mo_flow =
	  $source * $cp_bubbler / ( 22400 * ( $pressure - $cp_bubbler ) )
	  ;                                               #[mol/min]
	my $sumflow  = get_sumflow();
	my $cp_dipte = 22400 * $mo_flow * $rp / $sumflow;    #[mbar]
	return $cp_dipte;
}

#-----------------------------------------------------------------------
#Procedura obliczajaca stezenie DMCd w reaktorze w mbar.
#działa na globalnym hashu %state

sub get_dmcd_pp {
	my $dmcd_temp = 21;                                  #stala temperatura DMCd
	my $source    = $state{'DMCd_1.source'};
	my $pressure  = $state{'DMCd_1.press'};
	my $rp        = $state{'ReactorPress'};

	my $cp_bubbler =
	  ( 10**( 7.764 - 1850 / ( $dmcd_temp + 273.15 ) ) ) /
	  0.76;    #stezenie w bubblerze w mbar
	my $MO_flow =
	  $source * $cp_bubbler / ( 22400 * ( $pressure - $cp_bubbler ) )
	  ;        #[mol/min]
	my $sumflow = get_sumflow();
	my $cp_dmcd = 22400 * $MO_flow * $rp / $sumflow;    #[mbar]
	return $cp_dmcd;
}

sub get_tdmaas_ppm {
	my $tdmaas_pmm;
	if (   $state{'TDMAAs_1.line'} =~ m/close|default/
		|| $state{'TDMAAs_1.run'} =~ m/close|default/ )
	{
		$tdmaas_ppm = "";
	}
	else {
		my $tdmaas_temp = 15;                          #stala temperatura TDMAAs
		my $source      = $state{'TDMAAs_1.source'};
		my $dilute      = $state{'TDMAAs_1.dilute'};
		my $inject      = $state{'TDMAAs_1.inject'};
		my $pressure    = $state{'TDMAAs_1.press'};
		my $rp          = $state{'ReactorPress'};
		if ( $state{'TDMAAs_1.source'} =~ m/default/ ) {
			$source = 20;
		}
		if ( $state{'TDMAAs_1.dilute'} =~ m/default/ ) {
			$dilute = 900;
		}
		if ( $state{'TDMAAs_1.inject'} =~ m/default/ ) {
			$inject = 50;
		}
		if ( $state{'TDMAAs_1.press'} =~ m/default/ ) {
			$press = 1500;
		}

		my $cp_bubbler =
		  ( 10**( 8.29 - 2391 / ( $tdmaas_temp + 273.15 ) ) ) /
		  0.76;    #stezenie w bubblerze w mbar
		my $MO_flow =
		  $source *
		  $inject /
		  ( $source + $dilute ) *
		  $cp_bubbler /
		  ( 22400 * ( $pressure - $cp_bubbler ) );    #[mol/min]
		my $sumflow = get_sumflow();
		$tdmaas_ppm = 10**6 * 22400 * $MO_flow / $sumflow;    #[ppm]
	}
	return $tdmaas_ppm;
}

sub get_ei_ppm {
	my $ei_ppm;
	if (   $state{'EI_1.line'} =~ m/close|default/
		|| $state{'EI_1.run'} =~ m/close|default/ )
	{
		$ei_ppm = "";
	}
	else {
		my $ei_temp  = 0;                        #stala temperatura TDMAAs
		my $source   = $state{'EI_1.source'};
		my $dilute   = $state{'EI_1.dilute'};
		my $inject   = $state{'EI_1.inject'};
		my $pressure = $state{'EI_1.press'};
		my $rp       = $state{'ReactorPress'};
		if ( $state{'EI_1.source'} =~ m/default/ ) {
			$source = 1;
		}
		if ( $state{'EI_1.dilute'} =~ m/default/ ) {
			$dilute = 100;
		}
		if ( $state{'EI_1.inject'} =~ m/default/ ) {
			$inject = 50;
		}
		if ( $state{'EI_1.press'} =~ m/default/ ) {
			$press = 1800;
		}

		my $cp_bubbler =
		  ( 10**( 7.877 - 1715 / ( $ei_temp + 273.15 ) ) ) /
		  0.76;    #stezenie w bubblerze w mbar
		my $MO_flow =
		  $source *
		  $inject /
		  ( $source + $dilute ) *
		  $cp_bubbler /
		  ( 22400 * ( $pressure - $cp_bubbler ) );    #[mol/min]
		my $sumflow = get_sumflow();
		$ei_ppm = 10**6 * 22400 * $MO_flow / $sumflow;    #[ppm]
	}
	return $ei_ppm;
}

###############################################################################################
#funkcja wstawiajaca dane do bazy
#arg1 to string z nazwa tabeli
#arg2 to string z nazwami kolumn w nawiasie, rozdzielonych przecinkami
#arg3 to string z wartosciami do wstawienia w nawiasach rozdzielonych przecinkami np: (val1,val2),(val3,val4)...
sub insert {

	my $tabela =
	  @_[0];    #string z labelem, ktorego obecnosc mamy sprawdzic w bazie
	my $kolumny  = @_[1];
	my $wartosci = @_[2];

	# connect
	my $dbh =
	  DBI->connect( $connection_string, $user, $password,
		{ 'RaiseError' => 1 } );

	# execute INSERT query
	my $rows = $dbh->do("INSERT INTO $tabela $kolumny VALUES $wartosci");

	print "Inserted $rows row(s) into $tabela\n";
}
#############################################################################################
###############################################################################################
#funkcja usuwajaca dane z bazy!!!
sub delete_from {

	my $string = @_[0];    #string usuwajacy

	# connect
	my $dbh =
	  DBI->connect( $connection_string, $user, $password,
		{ 'RaiseError' => 1 } );

	# execute
	my $rows = $dbh->do($string);

	print "\nUsunieto $rows wierszy!\n";
}
#####################################################################
sub analyse_step {

  my $step = @_[0];
	if ( $step =~ m/\s*loop\s*(\d+)\s*\{(.*?)\}/sg ) {
		$loop_count = $1;
		my $loop_body = $2;
		my @loop_steps=recs_split($loop_body);		

		foreach my $lstep (@loop_steps) {
			analyse_step($lstep);
		}
		$loop_count = 1;
		
	}

#rozpoznawanie zwyklych krokow - z czasem trwania na poczatku, wyciecie czasu trwania ze stringa
	elsif ( $step =~ m/^\s*(\d*[:.]?\d*:?\d+)\s+(.*)/is ) {

		#generowanie hasha pustego
		my %out_hash = %zero_hash;

		my $step_count = 1;    #w przypadku zwyklego kroku ilosc jego powtorzen wynosi 1
		my $step_time = $1
		  ;  #w przypadku zwyklego kroku  czas jego trwania z pierwszego wiersza
		my $step_body = $2;
		$step_body =~ s/\s*$//s;
		if ( $step_time =~ m/(\d*):(\d*):(\d*)/ ) {
			$step_time = $1 * 3600 + $2 * 60 + $3;
		}
		elsif ( $step_time =~ m/(\d*):(\d*)/ ) {
			$step_time = $1 * 60 + $2;
		}

		#kod analizujacy i dodajacy kazdy rozkaz do %state
		#TODO zabezpieczyc kod przed przecinkami w Message!
		#informacja w recepturze - opis kroku
		if ( $step_body =~ s/"(.*?)"\s*,*// ) {
			$key = "Message";
			$value = $1; 	
			$state{$key} = $value;
		}
		# i dalej juz nie powinno byc problemow z przecinkami

		for ($step_body) {
	            s/^\s+//;
	            s/\s+$//;
        	}
		my @orders = split( /,/, $step_body );

#zwykle kroki: 1 jako liczba petli i Suma jako czas trwania wyciagniety z pierwszego kroku.
		foreach $s (@orders) {
			my @k_v = order_split($s);
			$state{ $k_v[0]->[0] } = $k_v[0]->[1];
		}
		state_step_actualization($step_body);

		#		$out_hash{'flow'}=$state{'flow'};

		#tutaj sprawdzenie warunkow na osadzanie AlGaAs
		#wywolanie procedury zwracajacej 1 lub 0 dla serii warunkow
		if ( algaas_check() || gaas_check() || alas_check() ||inas_check() || ingaasp_check() ||  inalgaas_check() || ingaalp_check() || gap_check() || alp_check() || inp_check() ) {

			$count = $count + 1;    #zwiekszenie licznika warstw
			my @tab = loop2table($step);
			my @sih4;
			if (   $state{'SiH4_1.line'} =~ m/open/is
				&& $state{'SiH4_1.run'} =~ m/open/is )
			{
				$out_hash{"SiH4_1"}    = $state{'SiH4_1.source'}."/".$state{'SiH4_1.dilute'}."/".$state{'SiH4_1.inject'};
			}
			my @ei;
			if (   $state{'DEZn_1.line'} =~ m/open/is
				&& $state{'DEZn_1.run'} =~ m/open/is )
			{
				$out_hash{"DEZn_1"}    = $state{'DEZn_1.source'}."/".$state{'DEZn_1.dilute'}."/".$state{'DEZn_1.inject'};
			}

			#TODO stezenia powinny byc w mbar lub ppm, aby nie przeliczac ich przez zewnetrzne programy
			$out_hash{"Step"} = $count;
			$out_hash{"Loops"}    = $loop_count;
			$out_hash{"Time"}      = $step_time;
			$out_hash{"TMGa_1"}    = get_source_flow('TMGa_1');
			$out_hash{"TMGa_2"}    = get_source_flow('TMGa_2');
			$out_hash{"TMAl_1"}    = get_source_flow('TMAl_1');
			$out_hash{"TMIn_1"}    = get_source_flow('TMIn_1');
			$out_hash{"TMIn_2"}    = get_source_flow('TMIn_2');
			$out_hash{"AsH3_1"}    = get_source_flow('AsH3_1');
			$out_hash{"PH3_1"}     = get_source_flow('PH3_1');
			$out_hash{"Temp."}    = $state{'ReactorTemp'};
			$out_hash{"Press"}    = $state{'ReactorPress'};
			$out_hash{"GrTemp"}    = $state{'ReactorTemp'};
			$out_hash{"Sumflow"}    = get_upperflow() . "/" . get_lowerflow();
			$out_hash{"Message"}    = $state{'Message'};

			push @out_tab, \%out_hash;
		}
	}

	#until
	elsif ( $step =~ s/(.*?),\s*until.*/\1/s ) {

		#po wycieciu warunku dodajemy do %state reszte rozkazow
		my $step_count = 1;    #w przypadku untila tez 1
		my $step_time  = 0
		  ; #w przypadku untila czas na 0 ustawimy, ale prawdopodobnie krok z untilem nigdy nie bedzie mial zadnego osadzania?
		    #tylko ewentualnie do rozpoznawania nukleacji mogloby sie przydac kiedys...
		    #kod analizujacy i dodajacy kazdy rozkaz do %state
		for ($step) {
	            s/^\s+//;
	            s/\s+$//;
        	}
		my @orders = split( /,/, $step );

#zwykle kroki: 1 jako liczba petli i Suma jako czas trwania wyciagniety z pierwszego kroku.
		foreach $s (@orders) {
			my @k_v = order_split($s);
			$state{ $k_v[0]->[0] } = $k_v[0]->[1];
		}

		#TODO tutaj tez zapis?
	}

	elsif ( $step =~ m/LeakTest/is ) {

		#empty now
	}

	elsif ( $step =~ m/(\w+)/is ) {

		#empty now
		print("Prawdopodobnie makro: $1\n");
	}

	#nierozpoznany krok, error!
	else {
		print("\n\nNierozpoznany krok!\n\n");
		exit;
	}

	#sprawdzenie czy azot do bubblerow sie nie dostanie!
	unless ( N2_in_MO_check() ) {
		print("\n\n$step\n\n");
		print("\n\nAZOT W BUBBLERACH!! POPRAW RECEPTURE!!\n\n");
		exit;
	}
}

