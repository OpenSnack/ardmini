#!/bin/bash

set -e

VERSION=004

SAVEIFS=$IFS
IFS='\'
SKIP=1
UPDATING=true
IGNORE=
SELECT=

usage(){
  echo -e "usage: ./ardmini.sh -f path [-s index] [-aceiq]\n"
  echo options:
  echo "-a   same as -cei"
  echo "-c   enables copying *.app in source to /Applications"
  echo "-e   enables executing *.sh in source"
  echo "-f   specifies the source folder (REQUIRED)"
  echo "-h   displays this message"
  echo "-i   enables installing *.pkg from source"
  echo "-n   skips the indices specified (numbers separated by commas, 1 is top of folder)"
  echo "-q   suppresses 'skipping' messages"
  echo "-s   skip to index in source folder (1 is top of folder)"
  echo "-u   suppresses updates"
  echo "-y   only processes the indices specified (see -n)"
  exit 0
}

update(){
  AVAILABLE=$(curl -s -r 29-31 https://raw.githubusercontent.com/snackthyme/ardmini/master/ardmini.sh)
  if [[ $AVAILABLE -gt $VERSION ]]
  then
    echo $(tput setaf 2)updating...$(tput sgr0)
    curl -s -o $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/ardmini.sh https://raw.githubusercontent.com/snackthyme/ardmini/master/ardmini.sh
    if [[ -s $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/ardmini.sh ]]
    then
      echo $(tput setaf 2)successful, run ardmini again$(tput sgr0)
      exit 0
    else
      echo $(tput setaf 1)failed$(tput sgr0)
      echo try updating later, or use -u to suppress updates
      exit 1
    fi
  fi
}

while getopts ":aceihquf:n:s:y:" opt; do
  case $opt in
    a)
    COPY=true
    INSTALL=true
    SHELL=true
      ;;
    c)
      COPY=true
      ;;
    e)
      SHELL=true
      ;;
    i)
      INSTALL=true
      ;;
    h)
      usage
      ;;
    q)
      NOSKIPMESSAGE=true
      ;;
    u)
      UPDATING=false
      ;;
    f)
      SOURCE=$(echo $OPTARG | sed 's/\/$//;s/\/\//\//g')
      FILE=true
      ;;
    n)
      FILTER=$(echo $OPTARG | sed 's/[0-9]*/&d;/g;s/,//g;s/$/p/')
      IGNORING=true
      ;;
    s)
      if [[ $OPTARG -lt 1 ]]
      then
        echo -s requires a positive integer, see -h
        exit 1
      else
        SKIP=$OPTARG
      fi
      SKIPPING=true
      ;;
    y)
      FILTER=$(echo $OPTARG | sed 's/[0-9]*/&p;/g;s/,//g')
      SELECTING=true
      ;;
    :)
      echo "a flag is missing an argument (-f, -n, -s, or -y), see -h"
      exit 1
      ;;
    \?)
      echo "Invalid option: -$OPTARG"
      exit 1
      ;;
  esac
done

if [ "$(id -u)" != "0" ]; then
   echo "script must be run as root"
   exit 1
fi

if [[ $UPDATING == true ]]
then
  update
fi

if [[ $FILE != true ]]
then
  echo -f must be specified, see -h
  exit 1
fi

if [[ $IGNORING && $SELECTING ]] || [[ $IGNORING && $SKIPPING ]] || [[ $SELECTING && $SKIPPING ]]
then
  echo -e "no combination of -s, -n or -y can be used at the same time"
  exit 1
fi

if [[ $IGNORING != true && $SELECTING != true ]]
then
  FILTER=p
fi

echo Started `date`
find "$SOURCE" -maxdepth 1 -not -path '*/\.*' | sed '1d' | sed -n "$FILTER" | while read f; do
  if [[ $SKIP != 1 ]]
  then
    let "SKIP -= 1"
  elif [[ $f == *.app && $COPY == true ]]
  then
    if [[ -e /Applications/$(basename $f) ]]
    then
      echo $(tput setaf 4)replacing$(tput sgr0) /Applications/$(basename $f)
      rm -rf /Applications/$(basename $f)
      cp -R "$f" /Applications/$(basename $f)
    else
      echo $(tput setaf 4)copying$(tput sgr0) "$f" to /Applications
      cp -R "$f" /Applications/$(basename $f)
    fi
  elif [[ $f == *.pkg && $INSTALL == true ]]
  then
    echo $(tput setaf 4)installing$(tput sgr0) "$f"
    installer -pkg "$f" -target /
  elif [[ $f == *.sh && $f != *ardmini.sh && $SHELL == true ]]
  then
    echo $(tput setaf 4)executing$(tput sgr0) "$f"
    chmod +x "$f"
    sh "$f"
  elif [[ $NOSKIPMESSAGE != true ]]
  then
    echo $(tput setaf 5)skipping$(tput sgr0) "$f"
  else
    continue
  fi
done

echo $(tput setaf 2)done$(tput sgr0)

IFS=$SAVEIFS
