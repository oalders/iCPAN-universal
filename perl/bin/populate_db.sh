#!/bin/sh

perl bin/update_db.pl --table authors
perl bin/update_db.pl --table distributions 
perl bin/update_db.pl --table modules 
