#!/bin/bash

echo Placing Bastille-related files in appropriate places...
echo ...
echo Do not forget to get perl-Tk installed before running Bastille.
mkdir /usr/share/Bastille /usr/lib/Bastille /usr/share/Bastille/Questions /usr/share/Bastille/OSMap
cp Modules.txt {,in}complete.xbm /usr/share/Bastille/
cp Bastille/*.pm Bastille_{Tk,Curses}.pm /usr/lib/Bastille/
cp InteractiveBastille BastilleBackEnd RevertBastille bin/bastille /usr/sbin/
cp bin/Bastille /usr/sbin/
cp Questions/* /usr/share/Bastille/Questions/
cp OSMap/* /usr/share/Bastille/OSMap
cp Localizable.strings /usr/share/Bastille/
cp StartupParameters.plist /usr/share/Bastille/
cp hosts.allow /usr/share/Bastille/

# New Weights file(s).
cp Weights.txt /usr/share/Bastille
# Castle graphic
cp bastille.jpg /usr/share/Bastille/
# Javascript file
cp wz_tooltip.js /usr/share/Bastille/
cp Credits /usr/share/Bastille

