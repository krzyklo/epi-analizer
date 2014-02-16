A Perl script which parse Aixtron's EPI recipes and extract to standard output (and CSV file) main parameters of detected layers. It allows to quickly and easily check whether there are no simple errors and whether complex recipes are in agreement with plans. REQUIREMENTS: PERL which could be downloaded from website: http://www.activestate.com/activeperl/downloads

USAGE: 
To start you need to write: 
  perl epi-analizer.pl name_of_recipe_file.epi

SHORT DESCRIPTION: Recipe are split by steps, and then state of the deposition system are tracked by %state hash, where state of the devices are updated at every step/order. At the end of every step there run deposition checks against %state of the deposition system, which detects that GaN, AlGaN, InGaN etc. are deposited by checking state of LINE/RUN valves and reactor temperature. In case of successful check for deposition, state of some basic system properties are recorded into %out_hash which are then added to @out_table. At the end of the recipe content of @out_table are printed out at std output and to CSV file.

TODO:
    commas in Messages should be avoided because script could treat them as separator of orders
    some more advanced recipe language constructions are not parsed eg. follow
    newer versions of Cace allows recipe to be splited into a few of EPI files, epi-analizer is developed for quite old versions of CACE (~2005), therefore newer language constructions could not work. I could try to add new features if someone provide me some examples of recipes used in newer Aixtron systems.

A lot of settings are now hardcoded, but in future they may be extracted into configuration files:
   - initial state of the deposition system could be read out from BaseState.epi file.
   - probably it would be desirable to give the users abilibty to define their own conditions on detecting deposition in CSV file.

I hope that this script will decrease the amount of recipe errors and ease a little life of MOCVD engineers. 

epi-analizer, was written by Krzysztof Kłos, klos.krzysztof@gmail.com 
